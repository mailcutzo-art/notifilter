package art.mailcutzo.notifilter

import android.net.Uri
import android.service.notification.Condition
import android.service.notification.ConditionProviderService

/** Inactive by design until device compatibility validation is implemented. */
class QuietConditionProvider : ConditionProviderService() {
    override fun onConnected() = Unit
    override fun onSubscribe(conditionId: Uri) {
        notifyCondition(Condition(conditionId, "Quiet Mode compatibility not verified", Condition.STATE_FALSE))
    }
    override fun onUnsubscribe(conditionId: Uri) = Unit
}
