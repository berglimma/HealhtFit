package com.healthfit.core.billing

import android.app.Activity
import android.content.Context
import com.android.billingclient.api.AcknowledgePurchaseParams
import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.BillingClientStateListener
import com.android.billingclient.api.BillingFlowParams
import com.android.billingclient.api.BillingResult
import com.android.billingclient.api.PendingPurchasesParams
import com.android.billingclient.api.ProductDetails
import com.android.billingclient.api.Purchase
import com.android.billingclient.api.QueryProductDetailsParams
import com.android.billingclient.api.QueryPurchasesParams
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Play Billing for the same plan catalog as iOS (same product id strings).
 * Entitlement stays on this device. Do not write a new Firestore entitlement
 * document — iOS reads StoreKit, not a shared purchase record.
 */
class BillingGateway(context: Context) {

    private val appContext = context.applicationContext
    private val prefs = appContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private val _connected = MutableStateFlow(false)
    val connected: StateFlow<Boolean> = _connected.asStateFlow()

    private val _products = MutableStateFlow<List<ProductDetails>>(emptyList())
    val products: StateFlow<List<ProductDetails>> = _products.asStateFlow()

    private val _activeProductId = MutableStateFlow(prefs.getString(KEY_ACTIVE, null))
    val activeProductId: StateFlow<String?> = _activeProductId.asStateFlow()

    private val client = BillingClient.newBuilder(appContext)
        .setListener { result, purchases ->
            if (result.responseCode == BillingClient.BillingResponseCode.OK) {
                handlePurchases(purchases.orEmpty())
            }
        }
        .enablePendingPurchases(
            PendingPurchasesParams.newBuilder().enableOneTimeProducts().build()
        )
        .build()

    fun startConnection() {
        client.startConnection(object : BillingClientStateListener {
            override fun onBillingSetupFinished(result: BillingResult) {
                val ok = result.responseCode == BillingClient.BillingResponseCode.OK
                _connected.value = ok
                if (ok) {
                    querySubscriptions(PRODUCT_IDS)
                    restorePurchases()
                }
            }

            override fun onBillingServiceDisconnected() {
                _connected.value = false
            }
        })
    }

    fun querySubscriptions(productIds: List<String>) {
        if (!_connected.value || productIds.isEmpty()) return
        val products = productIds.map {
            QueryProductDetailsParams.Product.newBuilder()
                .setProductId(it)
                .setProductType(BillingClient.ProductType.SUBS)
                .build()
        }
        val params = QueryProductDetailsParams.newBuilder().setProductList(products).build()
        client.queryProductDetailsAsync(params) { result, details ->
            if (result.responseCode == BillingClient.BillingResponseCode.OK) {
                _products.value = details
            }
        }
    }

    fun launchPurchase(activity: Activity, productId: String): Boolean {
        val details = _products.value.firstOrNull { it.productId == productId } ?: return false
        val offer = details.subscriptionOfferDetails?.firstOrNull() ?: return false
        val productParams = BillingFlowParams.ProductDetailsParams.newBuilder()
            .setProductDetails(details)
            .setOfferToken(offer.offerToken)
            .build()
        val flow = BillingFlowParams.newBuilder()
            .setProductDetailsParamsList(listOf(productParams))
            .build()
        val result = client.launchBillingFlow(activity, flow)
        return result.responseCode == BillingClient.BillingResponseCode.OK
    }

    fun restorePurchases() {
        if (!_connected.value) return
        val params = QueryPurchasesParams.newBuilder()
            .setProductType(BillingClient.ProductType.SUBS)
            .build()
        client.queryPurchasesAsync(params) { result, purchases ->
            if (result.responseCode == BillingClient.BillingResponseCode.OK) {
                handlePurchases(purchases)
            }
        }
    }

    fun formattedPrice(productId: String): String? {
        val details = _products.value.firstOrNull { it.productId == productId } ?: return null
        val phases = details.subscriptionOfferDetails
            ?.firstOrNull()
            ?.pricingPhases
            ?.pricingPhaseList
            .orEmpty()
        return phases.lastOrNull()?.formattedPrice
    }

    fun endConnection() {
        client.endConnection()
    }

    private fun handlePurchases(purchases: List<Purchase>) {
        val owned = purchases.filter { it.purchaseState == Purchase.PurchaseState.PURCHASED }
        owned.filter { !it.isAcknowledged }.forEach { purchase ->
            val params = AcknowledgePurchaseParams.newBuilder()
                .setPurchaseToken(purchase.purchaseToken)
                .build()
            client.acknowledgePurchase(params) { }
        }
        val active = owned
            .flatMap { it.products }
            .mapNotNull { id -> PLANS.firstOrNull { it.productId == id } }
            .maxByOrNull { it.rank }
        val productId = active?.productId
        _activeProductId.value = productId
        prefs.edit().putString(KEY_ACTIVE, productId).apply()
    }

    data class PlanOffer(
        val name: String,
        val productId: String,
        val period: String,
        val referencePrice: String,
        val rank: Int,
    )

    companion object {
        private const val PREFS = "healthfit_billing"
        private const val KEY_ACTIVE = "active_product_id"

        val PLANS = listOf(
            PlanOffer("Básico", "healthfit.plan.basic.monthly", "Mensal", "R$ 9,90", 1),
            PlanOffer("Fit", "healthfit.plan.fit.monthly", "Mensal", "R$ 12,90", 2),
            PlanOffer("IA Plus", "healthfit.plan.ai.monthly", "Mensal", "R$ 19,90", 3),
            PlanOffer("Completo", "healthfit.plan.complete.monthly", "Mensal", "R$ 24,90", 4),
            PlanOffer("Básico", "healthfit.plan.basic.yearly", "Anual", "R$ 94,90", 1),
            PlanOffer("Fit", "healthfit.plan.fit.yearly", "Anual", "R$ 123,90", 2),
            PlanOffer("IA Plus", "healthfit.plan.ai.yearly", "Anual", "R$ 190,90", 3),
            PlanOffer("Completo", "healthfit.plan.complete.yearly", "Anual", "R$ 239,90", 4),
        )

        val PRODUCT_IDS = PLANS.map { it.productId }
    }
}
