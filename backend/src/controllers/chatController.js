const supabase = require('../config/supabaseClient');
const { sendPushNotification } = require('../utils/pushNotifier');

const sendMessage = async (req, res) => {
    const { booking_id, text, sender_id } = req.body;

    const final_sender_id = req?.user?.id || sender_id;

    if (!final_sender_id) {
        return res.status(400).json({ success: false, error: "Sender ID is missing" });
    }

    try {

        const { data: booking, error: bookingError } = await supabase
            .from('bookings')
            .select('driver_id, tourist_id')
            .eq('id', booking_id)
            .single();

        if (bookingError || !booking) {
            return res.status(404).json({ success: false, error: "Booking not found" });
        }

        const { data, error } = await supabase
            .from('messages')
            .insert([{ booking_id, sender_id: final_sender_id, text }])
            .select();

        if (error) throw error;

        let targetId = null;
        if (final_sender_id === booking.tourist_id) {
            targetId = booking.driver_id;
        } else if (final_sender_id === booking.driver_id) {
            targetId = booking.tourist_id;
        }

        if (targetId) {
            await sendPushNotification(targetId, text);
        } else {
            console.warn("⚠️ Target ID missing, Notification not sent.");
        }

        res.status(201).json({ success: true, message: "Message sent!", data: data[0] });
    } catch (err) {
        console.error("💥 Error sending message:", err);
        res.status(500).json({ success: false, error: "Server Error" });
    }
};

const getMessages = async (req, res) => {
    const { booking_id } = req.params;

    try {
        const { data, error } = await supabase
            .from('messages')
            .select('*')
            .eq('booking_id', booking_id)
            .order('created_at', { ascending: true });

        if (error) throw error;

        res.status(200).json({ success: true, messages: data });
    } catch (err) {
        console.error("💥 Error fetching messages:", err);
        res.status(500).json({ success: false, error: "Server Error" });
    }
};

const markMessagesAsRead = async (req, res) => {
    const { booking_id, user_id } = req.body;

    try {

        const { error } = await supabase
            .from('messages')
            .update({ is_read: true })
            .eq('booking_id', booking_id)
            .neq('sender_id', user_id)
            .eq('is_read', false);

        if (error) throw error;

        res.status(200).json({ success: true, message: "Messages marked as read" });
    } catch (err) {
        console.error("💥 Error marking messages as read:", err);
        res.status(500).json({ success: false, error: "Server Error" });
    }
};

module.exports = { sendMessage, getMessages, sendPushNotification, markMessagesAsRead };
