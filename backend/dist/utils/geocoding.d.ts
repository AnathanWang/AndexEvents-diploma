export interface GeocodingResult {
    latitude: number;
    longitude: number;
    formattedAddress: string;
}
export declare const geocodeAddress: (address: string) => Promise<GeocodingResult | null>;
export declare const reverseGeocode: (latitude: number, longitude: number) => Promise<string | null>;
export declare const calculateDistance: (lat1: number, lon1: number, lat2: number, lon2: number) => number;
//# sourceMappingURL=geocoding.d.ts.map