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
 * Play Billing gateway (StoreKit 2 analogue).
 * Product IDs must be created in Play Console — do NOT reuse App Store product IDs blindly.
 * Entitlements on device stay local until a dual-platform entitlement strategy is agreed;
 * do not write new Firestore entitlement docs that iOS does not already read.
 */
class BillingGateway(context: Context) {

    private val _connected = MutableStateFlow(false)
    val connected: StateFlow<Boolean> = _connected.asStateFlow()

    private val _products = MutableStateFlow<List<ProductDetails>>(emptyList())
    val products: StateFlow<List<ProductDetails>> = _products.asStateFlow()

    private val client = BillingClient.newBuilder(context)
        .setListener { _, _ -> /* purchases updated — Phase 1 stub */ }
        .enablePendingPurchases(
            PendingPurchasesParams.newBuilder().enableOneTimeProducts().build()
        )
        .build()

    fun startConnection() {
        client.startConnection(object : BillingClientStateListener {
            override fun onBillingSetupFinished(result: BillingResult) {
                _connected.value = result.responseCode == BillingClient.BillingResponseCode.OK
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

    fun launchPurchase(activity: Activity, details: ProductDetails) {
        val offer = details.subscriptionOfferDetails?.firstOrNull() ?: return
        val productParams = BillingFlowParams.ProductDetailsParams.newBuilder()
            .setProductDetails(details)
            .setOfferToken(offer.offerToken)
            .build()
        val flow = BillingFlowParams.newBuilder()
            .setProductDetailsParamsList(listOf(productParams))
            .build()
        client.launchBillingFlow(activity, flow)
    }

    fun endConnection() {
        client.endConnection()
    }

    companion object {
        /** Placeholder SKUs — create in Play Console before enabling purchase UI. */
        val PHASE1_PRODUCT_IDS = listOf(
            "healthfit_fit_monthly",
            "healthfit_completo_monthly",
        )
    }
}
