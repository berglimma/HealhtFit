package com.healthfit.android

import android.app.Application
import com.google.firebase.FirebaseApp
import com.healthfit.core.auth.AuthRepository
import com.healthfit.core.auth.FirebaseAuthRepository
import com.healthfit.core.auth.OfflineAuthRepository
import com.healthfit.core.billing.BillingGateway
import com.healthfit.core.health.HealthConnectGateway
import com.healthfit.core.workout.DefaultWorkoutRepository
import com.healthfit.core.workout.WorkoutRepository

class HealthFitApp : Application() {
    lateinit var authRepository: AuthRepository
        private set
    lateinit var workoutRepository: WorkoutRepository
        private set
    lateinit var healthConnectGateway: HealthConnectGateway
        private set
    lateinit var billingGateway: BillingGateway
        private set

    override fun onCreate() {
        super.onCreate()
        val firebaseReady = runCatching { FirebaseApp.initializeApp(this) }.isSuccess &&
            FirebaseApp.getApps(this).isNotEmpty()

        authRepository = if (firebaseReady) {
            runCatching { FirebaseAuthRepository() }.getOrElse { OfflineAuthRepository() }
        } else {
            OfflineAuthRepository()
        }
        workoutRepository = DefaultWorkoutRepository()
        healthConnectGateway = HealthConnectGateway(this)
        billingGateway = BillingGateway(this).also { it.startConnection() }
    }
}
