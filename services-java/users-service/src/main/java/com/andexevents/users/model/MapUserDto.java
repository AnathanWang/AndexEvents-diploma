package com.andexevents.users.model;

public record MapUserDto(
        String id,
        String displayName,
        String photoUrl,
        Integer age,
        Double lastLatitude,
        Double lastLongitude
) {
}
