const supabase = require('../config/supabaseClient');
const { sendPushNotification } = require('../utils/pushNotifier');

const MAX_OFFLINE_SYNC_NOTIFICATION_AGE_MS = 30 * 60 * 1000;

/**
 * Notify all currently active (is_active = true) drivers except the reporting driver.
 */
const notifyActiveDriversOfSighting = async (sighting, reportingDriverId) => {
    try {
        const { data: activeDrivers, error: driversError } = await supabase
            .from('driver_profiles')
            .select('id')
            .eq('is_active', true)
            .neq('id', reportingDriverId);

        if (driversError) {
            console.error('⚠️ Error fetching active drivers for sighting notification:', driversError.message);
            return;
        }

        const recipientIds = (activeDrivers || []).map((d) => d.id).filter(Boolean);
        if (recipientIds.length === 0) {
            return;
        }

        const animalType = sighting.animal_type || 'Wildlife';
        await sendPushNotification(
            recipientIds,
            `A fellow driver spotted a ${animalType}. Tap to view on the map.`,
            {
                title: `🐾 New ${animalType} Sighting!`,
                data: {
                    type: 'NEW_SIGHTING',
                    sighting_id: sighting.id ? sighting.id.toString() : '',
                    animal_type: animalType,
                    location_lat: Number(sighting.location_lat),
                    location_lng: Number(sighting.location_lng),
                },
            }
        );
    } catch (notifyErr) {
        console.error('⚠️ Failed to notify active drivers of sighting:', notifyErr);
    }
};

const logSighting = async (req, res) => {
    const { driver_id, animal_type, location_lat, location_lng, description, recorded_at } = req.body;

    if (!driver_id || !animal_type || location_lat === undefined || location_lng === undefined) {
        return res.status(400).json({ success: false, error: "Missing required fields for sighting" });
    }

    try {

        const { data, error } = await supabase
            .from('sightings')
            .insert([
                {
                    driver_id: driver_id,
                    animal_type: animal_type,
                    location_lat: location_lat,
                    location_lng: location_lng,
                    description: description || 'Logged via mobile map'
                }
            ])
            .select();

        if (error) throw error;

        const savedSighting = data[0];

        // Skip push notifications for stale offline-queued sightings synced much later
        let shouldNotify = true;
        if (recorded_at) {
            const recordedTime = new Date(recorded_at).getTime();
            if (!Number.isNaN(recordedTime) && (Date.now() - recordedTime) > MAX_OFFLINE_SYNC_NOTIFICATION_AGE_MS) {
                shouldNotify = false;
            }
        }

        if (shouldNotify) {
            await notifyActiveDriversOfSighting(savedSighting, driver_id);
        }

        res.status(201).json({ success: true, message: "Sighting logged successfully!", data: savedSighting });
    } catch (err) {
        console.error("💥 Error logging sighting:", err);
        res.status(500).json({ success: false, error: "Server Error while saving sighting" });
    }
};

const getSightings = async (req, res) => {
    try {

        const timeLimit = new Date(Date.now() - 2 * 60 * 60 * 1000).toISOString();

        const { data, error } = await supabase
            .from('sightings')
            .select('*')
            .gte('created_at', timeLimit)
            .order('created_at', { ascending: false });

        if (error) throw error;

        const animalTimeLimits = {
            'elephant': 60, // Elephant stays in an area ~60 minutes
            'leopard': 30,  // Leopard moves quickly ~30 minutes
            'bear': 30,     // Bear ~30 minutes
            'peacock': 20,  // Peacock/Birds ~20 minutes
            'deer': 15,     // Deer flees quickly ~15 minutes
            'other': 15
        };

        const now = new Date();

        const activeSightings = data.filter(sighting => {
            const sightingTime = new Date(sighting.created_at);

            const diffInMinutes = (now - sightingTime) / (1000 * 60);

            const maxAllowedMinutes = animalTimeLimits[(sighting.animal_type || '').toLowerCase()] || 60;

            return diffInMinutes <= maxAllowedMinutes;
        });

        res.status(200).json({ success: true, data: activeSightings });
    } catch (err) {
        console.error("💥 Error fetching sightings:", err);
        res.status(500).json({ success: false, error: "Server Error while fetching sightings" });
    }
};

module.exports = { logSighting, getSightings };
