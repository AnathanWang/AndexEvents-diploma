import axios from 'axios';
import logger from './logger.js';

const YANDEX_GEOCODE_API = 'https://geocode-maps.yandex.ru/1.x/';
const API_KEY = process.env.YANDEX_MAPS_API_KEY || '';

export interface GeocodingResult {
  latitude: number;
  longitude: number;
  formattedAddress: string;
}

export const geocodeAddress = async (address: string): Promise<GeocodingResult | null> => {
  try {
    const response = await axios.get(YANDEX_GEOCODE_API, {
      params: {
        apikey: API_KEY,
        geocode: address,
        format: 'json',
        results: 1,
      },
    });

    const geoObject = response.data.response.GeoObjectCollection.featureMember[0]?.GeoObject;

    if (!geoObject) {
      logger.warn(`No geocoding results for address: ${address}`);
      return null;
    }

    const [longitude, latitude] = geoObject.Point.pos.split(' ').map(Number);
    const formattedAddress = geoObject.metaDataProperty.GeocoderMetaData.text;

    return {
      latitude,
      longitude,
      formattedAddress,
    };
  } catch (error) {
    logger.error('Geocoding error:', error);
    return null;
  }
};

export const reverseGeocode = async (
  latitude: number,
  longitude: number
): Promise<string | null> => {
  try {
    const response = await axios.get(YANDEX_GEOCODE_API, {
      params: {
        apikey: API_KEY,
        geocode: `${longitude},${latitude}`,
        format: 'json',
        results: 1,
      },
    });

    const geoObject = response.data.response.GeoObjectCollection.featureMember[0]?.GeoObject;

    if (!geoObject) {
      return null;
    }

    return geoObject.metaDataProperty.GeocoderMetaData.text;
  } catch (error) {
    logger.error('Reverse geocoding error:', error);
    return null;
  }
};

export const calculateDistance = (
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number
): number => {
  const R = 6371e3; // Earth's radius in meters
  const φ1 = (lat1 * Math.PI) / 180;
  const φ2 = (lat2 * Math.PI) / 180;
  const Δφ = ((lat2 - lat1) * Math.PI) / 180;
  const Δλ = ((lon2 - lon1) * Math.PI) / 180;

  const a =
    Math.sin(Δφ / 2) * Math.sin(Δφ / 2) +
    Math.cos(φ1) * Math.cos(φ2) * Math.sin(Δλ / 2) * Math.sin(Δλ / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

  return R * c; // Distance in meters
};
