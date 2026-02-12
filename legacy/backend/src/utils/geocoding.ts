/**
 * Geocoding utilities (Yandex)
 *
 * This module provides simple wrappers around Yandex Geocoding HTTP API:
 * - geocodeAddress(address): returns { latitude, longitude, formattedAddress } or null
 * - reverseGeocode(latitude, longitude): returns formatted address string or null
 * - calculateDistance(lat1, lon1, lat2, lon2): haversine distance in meters
 *
 * Environment variables
 * - YANDEX_MAPS_API_KEY
 *     The API key used for Yandex Geocode HTTP requests.
 *     On the backend, it is read from process.env.YANDEX_MAPS_API_KEY.
 *
 * Local development
 * - For local backend development you can place the key into `backend/.env`:
 *     YANDEX_MAPS_API_KEY=your_geocode_key
 *   backend/.env is listed in .gitignore and should not be committed.
 *
 * - Alternatively you can store the key in `secrets/yandex_geocode_api_key.txt`
 *   (the repo includes helper scripts to create this file). Then export it:
 *     export YANDEX_MAPS_API_KEY=$(cat secrets/yandex_geocode_api_key.txt)
 *
 * Notes
 * - This utility expects the standard Yandex Geocode response structure.
 * - Errors are logged via the project's logger and null is returned on failure.
 * - Keep production keys in CI secret storage; do not commit them to the repository.
 */

import axios from "axios";
import logger from "./logger.js";

const YANDEX_GEOCODE_API = "https://geocode-maps.yandex.ru/1.x/";
const API_KEY = process.env.YANDEX_MAPS_API_KEY || "";

export interface GeocodingResult {
  latitude: number;
  longitude: number;
  formattedAddress: string;
}

export const geocodeAddress = async (
  address: string,
): Promise<GeocodingResult | null> => {
  try {
    const response = await axios.get(YANDEX_GEOCODE_API, {
      params: {
        apikey: API_KEY,
        geocode: address,
        format: "json",
        results: 1,
      },
    });

    const geoObject =
      response.data.response.GeoObjectCollection.featureMember[0]?.GeoObject;

    if (!geoObject) {
      logger.warn(`No geocoding results for address: ${address}`);
      return null;
    }

    const [longitude, latitude] = geoObject.Point.pos.split(" ").map(Number);
    const formattedAddress = geoObject.metaDataProperty.GeocoderMetaData.text;

    return {
      latitude,
      longitude,
      formattedAddress,
    };
  } catch (error) {
    logger.error("Geocoding error:", error);
    return null;
  }
};

export const reverseGeocode = async (
  latitude: number,
  longitude: number,
): Promise<string | null> => {
  try {
    const response = await axios.get(YANDEX_GEOCODE_API, {
      params: {
        apikey: API_KEY,
        geocode: `${longitude},${latitude}`,
        format: "json",
        results: 1,
      },
    });

    const geoObject =
      response.data.response.GeoObjectCollection.featureMember[0]?.GeoObject;

    if (!geoObject) {
      return null;
    }

    return geoObject.metaDataProperty.GeocoderMetaData.text;
  } catch (error) {
    logger.error("Reverse geocoding error:", error);
    return null;
  }
};

export const calculateDistance = (
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number,
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
