
const axios = require('axios');
const crypto = require('crypto');

exports.init = {
    call: async function (commonObj, data) {
        if (data && data.grant_type == 'parcel_cost') {
            const { cutomerZip, receiverZip, width, length, height, weight, parcel_type_id } = data
            if (!cutomerZip || !receiverZip || !weight || !length || !width || !height) {
                return { SUCCESS: false, MESSAGE: "All parameters are required" };
            }

            if (weight <= 0 || length <= 0 || width <= 0 || height <= 0) {
                return { SUCCESS: false, MESSAGE: "Weight and dimensions must be positive values" };
            }

            const CONFIG = {
                DIMENSIONAL_FACTOR: 5000,
                BASE_WEIGHT: 5,        // kg
                BASE_RATE: 50,         // INR
                MIN_DISTANCE: 5,       // km
                WEIGHT_RATE: 10,       // INR per kg over base
            };

            try {

                const [cutomerZipRes, receiverZipRes] = await Promise.all([
                    commonObj.getData('zip_code', { where: [{ key: 'id', operator: 'is', value: cutomerZip }] }),
                    commonObj.getData('zip_code', { where: [{ key: 'id', operator: 'is', value: receiverZip }] })
                ]);

                if (!cutomerZipRes.SUCCESS || !cutomerZipRes.MESSAGE) {
                    return { SUCCESS: false, MESSAGE: 'Customer zip code not found' };
                }
                if (!receiverZipRes.SUCCESS || !receiverZipRes.MESSAGE) {
                    return { SUCCESS: false, MESSAGE: 'Receiver zip code not found' };
                }

                const deliveryModeRes = await commonObj.getData('delivery_mode', {
                    where: [{ key: 'status', operator: 'is', value: 1 }]
                });

                if (!deliveryModeRes.SUCCESS || !Array.isArray(deliveryModeRes.MESSAGE)) {
                    return { SUCCESS: false, MESSAGE: 'Failed to fetch delivery modes' };
                }

                const deliveryModes = deliveryModeRes.MESSAGE;

                const distanceKm = await this.estimateDistanceByZip(
                    cutomerZipRes.MESSAGE.code,
                    receiverZipRes.MESSAGE.code
                ) || CONFIG.MIN_DISTANCE;

                const volumetricWeight = (length * width * height) / CONFIG.DIMENSIONAL_FACTOR;
                const chargeableWeight = Math.max(weight, volumetricWeight);

                const weightSurcharge = chargeableWeight > CONFIG.BASE_WEIGHT
                    ? (chargeableWeight - CONFIG.BASE_WEIGHT) * CONFIG.WEIGHT_RATE
                    : 0;

                const baseCost = CONFIG.BASE_RATE + weightSurcharge;

                const deliveryOptions = deliveryModes.map(mode => {
                    const isAir = mode.category_name == 2;
                    const isExpress = mode.name.toLowerCase().includes('premium') || mode.name.toLowerCase().includes('express');

                    const rateMultiplier = isAir ? 2.5 : 1.0;
                    const surchargeRate = isAir ? 0.30 : 0.15;
                    const dailyDistance = isAir ? 1000 : 300;

                    const distanceCost = distanceKm * rateMultiplier * CONFIG.WEIGHT_RATE;
                    let totalCost = baseCost + distanceCost;
                    totalCost += totalCost * surchargeRate;

                    return {
                        id: mode.id,
                        mode: mode.name,
                        baseRate: CONFIG.BASE_RATE,
                        distance: parseFloat(distanceKm.toFixed(2)),
                        distanceCost: parseFloat(distanceCost.toFixed(2)),
                        actualWeight: parseFloat(weight.toFixed(2)),
                        volumetricWeight: parseFloat(volumetricWeight.toFixed(2)),
                        chargeableWeight: parseFloat(chargeableWeight.toFixed(2)),
                        weightSurcharge: parseFloat(weightSurcharge.toFixed(2)),
                        surchargeRate: surchargeRate * 100 + '%',
                        totalCost: parseFloat(totalCost.toFixed(2)),
                        estimatedDays: Math.max(1, Math.ceil(distanceKm / dailyDistance)),
                        currency: "INR",
                        isAir,
                        isExpress,
                        description: mode.description,
                        category: mode.category_name
                    };
                });

                return {
                    SUCCESS: true,
                    MESSAGE: {
                        summary: {
                            origin: cutomerZipRes.MESSAGE.code,
                            destination: receiverZipRes.MESSAGE.code,
                            actualDistance: parseFloat(distanceKm.toFixed(2)) + ' km'
                        },
                        options: deliveryOptions
                    }
                };
            } catch (error) {
                return { SUCCESS: false, error: "Error calculating delivery cost", MESSAGE: error.message };
            }
        } else if (data && data.grant_type == 'service_check') {
            const { pickupZip, deliveryZip } = data;
            if (!pickupZip || !deliveryZip) {
                return { SUCCESS: false, MESSAGE: "Please provide pickup zip code and delivery zip code" };
            }

            const [pickupZipRes, deliveryZipRes] = await Promise.all([
                commonObj.getData('branche_services_zipcode', {
                    reference: [{ type: 'JOIN', obj: 'zip_code', a: 'id', b: 'zip' }],
                    select: 'branche_services_zipcode.*, zip_code.code zipcode',
                    where: [{ key: 'zip_code.code', operator: 'is', value: pickupZip }]
                }),
                commonObj.getData('branche_services_zipcode', {
                    reference: [{ type: 'JOIN', obj: 'zip_code', a: 'id', b: 'zip' }],
                    select: 'branche_services_zipcode.*, zip_code.code zipcode',
                    where: [{ key: 'zip_code.code', operator: 'is', value: deliveryZip }]
                })
            ]);

            if (pickupZipRes.MESSAGE.length > 0 && deliveryZipRes.MESSAGE.length > 0) {
                return { SUCCESS: true, MESSAGE: 'Delivery service avalable' };
            } else {
                return { SUCCESS: false, MESSAGE: 'Delivery service not avalable' }
            }

        } else if (data && data.grant_type == 'generate_otp') {
            const {consignment_id} = data;
            if (!consignment_id || consignment_id == '') {
                return {SUCCESS:false , MESSAGE: 'Provide a consignment id'}
            }
            const consignmentRes = await commonObj.getData('consignment',{
                where: [{ 'key': 'id', 'operator':'id' , 'value' : consignment_id}]
            });

            if (!consignmentRes.SUCCESS || consignmentRes.MESSAGE?.id == null) {
                return { SUCCESS: false, MESSAGE: 'Please Provide a valid consignment id' }
            }
            const OTP = this.generateSecureOTP();
            const setconsignmentOtp = await commonObj.setData('consignment', {
                otp:OTP,
                id:consignment_id
            });
            if (setconsignmentOtp.SUCCESS) {
                return {SUCCESS:true ,MESSAGE:'OTP Send Successfully'}
            }else{
                return {SUCCESS:false, MESSAGE:'OTP not send'}
            }
        } else {
            return { SUCCESS: false, MESSAGE: "Unknown grant_type" };
        }
    },

    estimateDistanceByZip: async function (zip1, zip2) {
        const API_KEY = 'AIzaSyA69-MeLKvZK3gTNCzPEE7c90tnmJtjDzk';
        const baseUrl = 'https://maps.googleapis.com/maps/api/distancematrix/json';

        try {
            const response = await axios.get(baseUrl, {
                params: {
                    origins: zip1,
                    destinations: zip2,
                    key: API_KEY,
                    units: 'metric'
                }
            });

            if (response.data.status !== 'OK') {
                throw new Error(response.data.error_message || 'Distance API failed');
            }

            const element = response.data.rows[0]?.elements[0];
            if (!element || element.status !== 'OK') {
                throw new Error('No route found between locations');
            };
            return element.distance.value / 1000;
        } catch (error) {
            console.error('Google Maps API Error:', error);
            throw new Error('Failed to calculate distance');
        }
    },

    generateSecureOTP: function (length = 6) {
        const digits = '0123456789';
        let otp = '';
        const bytes = crypto.randomBytes(length);
        for (let i = 0; i < length; i++) {
            otp += digits[bytes[i] % 10];
        }
        return otp;
    }
};