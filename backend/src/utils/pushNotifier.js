/**
 * Shared OneSignal push notification helper.
 * Sends push notifications to one or more users via OneSignal external_id aliases.
 */

const ONESIGNAL_API_URL = 'https://onesignal.com/api/v1/notifications';
const MAX_EXTERNAL_IDS_PER_REQUEST = 2000;

/**
 * Send a push notification via OneSignal REST API.
 * @param {string|string[]} targetUserIds - One user ID or an array of user IDs (OneSignal external_id).
 * @param {string} messageText - Notification body text.
 * @param {Object} [options] - Optional title and custom data payload.
 * @param {string} [options.title] - Notification heading (defaults to 'GuideLanka: New Message').
 * @param {Object} [options.data] - Custom additionalData payload attached to the notification.
 */
const sendPushNotification = async (targetUserIds, messageText, options = {}) => {
    const ONESIGNAL_APP_ID = process.env.ONESIGNAL_APP_ID;
    const ONESIGNAL_REST_API_KEY = process.env.ONESIGNAL_REST_API_KEY;

    if (!ONESIGNAL_APP_ID || !ONESIGNAL_REST_API_KEY) {
        console.warn('⚠️ OneSignal credentials missing in environment; skipping push notification.');
        return;
    }

    const rawList = Array.isArray(targetUserIds) ? targetUserIds : [targetUserIds];
    const uniqueIds = [...new Set(rawList.filter(Boolean).map((id) => id.toString()))];

    if (uniqueIds.length === 0) {
        return;
    }

    const title = options.title || 'GuideLanka: New Message';
    const headers = {
        'Content-Type': 'application/json; charset=utf-8',
        'Authorization': `Basic ${ONESIGNAL_REST_API_KEY}`,
    };

    for (let i = 0; i < uniqueIds.length; i += MAX_EXTERNAL_IDS_PER_REQUEST) {
        const batch = uniqueIds.slice(i, i + MAX_EXTERNAL_IDS_PER_REQUEST);
        const payload = {
            app_id: ONESIGNAL_APP_ID,
            include_aliases: {
                external_id: batch,
            },
            target_channel: 'push',
            headings: { en: title },
            contents: { en: messageText },
        };

        if (options.data && typeof options.data === 'object') {
            payload.data = options.data;
        }

        try {
            const response = await fetch(ONESIGNAL_API_URL, {
                method: 'POST',
                headers,
                body: JSON.stringify(payload),
            });

            const result = await response.json();
            if (!response.ok) {
                console.error('❌ OneSignal API Error:', result);
            } else {
                console.log('Notification Sent Successfully:', result);
            }
        } catch (error) {
            console.error('Error sending OneSignal notification:', error);
        }
    }
};

module.exports = { sendPushNotification };
