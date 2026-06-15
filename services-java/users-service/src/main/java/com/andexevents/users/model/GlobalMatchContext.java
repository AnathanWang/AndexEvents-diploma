package com.andexevents.users.model;

import java.util.Collections;
import java.util.HashSet;
import java.util.Set;

public record GlobalMatchContext(
        Set<String> actionedUserIds,
        Set<String> incomingLikeUserIds,
        Set<String> mutualUserIds
) {
    public GlobalMatchContext {
        actionedUserIds = actionedUserIds == null ? Set.of() : Set.copyOf(actionedUserIds);
        incomingLikeUserIds = incomingLikeUserIds == null ? Set.of() : Set.copyOf(incomingLikeUserIds);
        mutualUserIds = mutualUserIds == null ? Set.of() : Set.copyOf(mutualUserIds);
    }

    public static GlobalMatchContext empty() {
        return new GlobalMatchContext(Set.of(), Set.of(), Set.of());
    }

    public Set<String> excludedCandidateIds() {
        Set<String> excluded = new HashSet<>();
        excluded.addAll(actionedUserIds);
        excluded.addAll(mutualUserIds);
        return Collections.unmodifiableSet(excluded);
    }
}
