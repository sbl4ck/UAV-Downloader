import Foundation

/// Static browse vocabulary, carried over from the project's own localization table
/// with the English labels selected (the desktop app defaulted to Traditional Chinese).
enum SiteCatalog {
    /// JableTV sidebar filter tags: (group, display name, url slug).
    static let jableTags: [(group: String, name: String, slug: String)] = [
        // Clothing
        ("Clothing", "Black Pantyhose", "black-pantyhose"),
        ("Clothing", "Knee Socks", "knee-socks"),
        ("Clothing", "Sportswear", "sportswear"),
        ("Clothing", "Nude Pantyhose", "flesh-toned-pantyhose"),
        ("Clothing", "Pantyhose", "pantyhose"),
        ("Clothing", "Glasses", "glasses"),
        ("Clothing", "Animal Ears", "kemonomimi"),
        ("Clothing", "Fishnets", "fishnets"),
        ("Clothing", "Swimsuit", "swimsuit"),
        ("Clothing", "School Uniform", "school-uniform"),
        ("Clothing", "Cheongsam", "cheongsam"),
        ("Clothing", "Wedding Dress", "wedding-dress"),
        ("Clothing", "Maid", "maid"),
        ("Clothing", "Kimono", "kimono"),
        ("Clothing", "Garter Stockings", "stockings"),
        ("Clothing", "Bunny Girl", "bunny-girl"),
        ("Clothing", "Cosplay", "Cosplay"),
        // Body
        ("Body", "Tan", "suntan"),
        ("Body", "Tall", "tall"),
        ("Body", "Flexible Body", "flexible-body"),
        ("Body", "Small Tits", "small-tits"),
        ("Body", "Beautiful Legs", "beautiful-leg"),
        ("Body", "Beautiful Butt", "beautiful-butt"),
        ("Body", "Tattoo", "tattoo"),
        ("Body", "Short Hair", "short-hair"),
        ("Body", "Hairless", "hairless-pussy"),
        ("Body", "Mature", "mature-woman"),
        ("Body", "Big Tits", "big-tits"),
        ("Body", "Girl", "girl"),
        ("Body", "Petite", "dainty"),
        // Acts
        ("Acts", "Facial", "facial"),
        ("Acts", "Footjob", "footjob"),
        ("Acts", "Anal Sex", "anal-sex"),
        ("Acts", "Spasms", "spasms"),
        ("Acts", "Squirting", "squirting"),
        ("Acts", "Deep Throat", "deep-throat"),
        ("Acts", "Kiss", "kiss"),
        ("Acts", "Oral Cumshot", "cum-in-mouth"),
        ("Acts", "Blowjob", "blowjob"),
        ("Acts", "Titjob", "tit-wank"),
        ("Acts", "Creampie", "creampie"),
        // Kinks
        ("Kinks", "Outdoor Exposure", "outdoor"),
        ("Kinks", "Gang Intrusion", "gang-intrusion"),
        ("Kinks", "Intrusion", "intrusion"),
        ("Kinks", "Training", "tune"),
        ("Kinks", "Bondage", "bondage"),
        ("Kinks", "Instant Penetration", "quickie"),
        ("Kinks", "Chikan", "chikan"),
        ("Kinks", "Chijo", "chizyo"),
        ("Kinks", "Male Masochist", "masochism-guy"),
        ("Kinks", "Drunk", "crapulence"),
        ("Kinks", "Soapland", "soapland"),
        ("Kinks", "Breast Milk", "breast-milk"),
        ("Kinks", "Piss", "piss"),
        ("Kinks", "Massage", "massage"),
        ("Kinks", "Group", "groupsex"),
        ("Kinks", "Restraints", "grip"),
        ("Kinks", "Humiliation", "insult"),
        ("Kinks", "10 Times a Day", "10-times-a-day"),
        ("Kinks", "3P", "3p"),
        // Story
        ("Story", "Black Man", "black"),
        ("Story", "Ugly Man", "ugly-man"),
        ("Story", "Temptation", "temptation"),
        ("Story", "Relatives", "kinship"),
        ("Story", "Virginity", "virginity"),
        ("Story", "Time Stop", "time-stop"),
        ("Story", "Revenge", "avenge"),
        ("Story", "Age Gap", "age-difference"),
        ("Story", "Giant Man", "giant"),
        ("Story", "Aphrodisiac", "love-potion"),
        ("Story", "In Front of Husband", "sex-beside-husband"),
        ("Story", "Affair", "affair"),
        ("Story", "Hypnosis", "hypnosis"),
        ("Story", "Voyeur", "private-cam"),
        ("Story", "Rainy Day", "rainy-day"),
        ("Story", "NTR", "ntr"),
        // Roles
        ("Roles", "Hostess/Sex Worker", "club-hostess-and-sex-worker"),
        ("Roles", "Doctor", "doctor"),
        ("Roles", "Fugitive", "fugitive"),
        ("Roles", "Nurse", "nurse"),
        ("Roles", "Teacher", "teacher"),
        ("Roles", "Flight Attendant", "flight-attendant"),
        ("Roles", "Team Manager", "team-manager"),
        ("Roles", "Widow", "widow"),
        ("Roles", "Investigator", "detective"),
        ("Roles", "Couple", "couple"),
        ("Roles", "Housekeeper", "housewife"),
        ("Roles", "Tutor", "private-teacher"),
        ("Roles", "Idol", "idol"),
        ("Roles", "Married Woman", "wife"),
        ("Roles", "Female Announcer", "female-anchor"),
        ("Roles", "OL", "ol"),
        // Places
        ("Places", "Magic Mirror Van", "magic-mirror"),
        ("Places", "Train", "tram"),
        ("Places", "Virgin", "first-night"),
        ("Places", "Prison", "prison"),
        ("Places", "Hot Spring", "hot-spring"),
        ("Places", "Bathhouse", "bathing-place"),
        ("Places", "Pool", "swimming-pool"),
        ("Places", "Car", "car"),
        ("Places", "Toilet", "toilet"),
        ("Places", "School", "school"),
        ("Places", "Library", "library"),
        ("Places", "Gym", "gym-room"),
        ("Places", "Convenience Store", "store"),
        // Misc
        ("Misc", "Filming", "video-recording"),
        ("Misc", "Debut / Retirement", "debut-retires"),
        ("Misc", "Variety Show", "variety-show"),
        ("Misc", "Holiday Theme", "festival"),
        ("Misc", "Fan Appreciation", "thanksgiving"),
        ("Misc", "Over 4 Hours", "more-than-4-hours"),
    ]

    static let jableTagGroups = [
        "Clothing", "Body", "Acts", "Kinks", "Story", "Roles", "Places", "Misc",
    ]
}

extension SiteCatalog {
    /// Slug -> English label, built from the tag table above.
    static let englishNamesBySlug: [String: String] = {
        var map: [String: String] = [:]
        for entry in jableTags {
            map[entry.slug.lowercased()] = entry.name
        }
        return map
    }()

    /// True when a string contains anything outside basic Latin — the signal that a
    /// site handed us a localized (CJK) label despite being asked for English.
    static func containsNonEnglish(_ text: String) -> Bool {
        text.unicodeScalars.contains { $0.value > 0x7F }
    }

    /// Guarantees an English menu label. Uses the known translation for a slug when we
    /// have one; otherwise turns the slug itself into a readable title ("big-tits" ->
    /// "Big Tits"). Falls back to the site's own label only when it is already English.
    static func englishName(slug: String, siteLabel: String) -> String {
        let key = slug.lowercased()
        if let known = englishNamesBySlug[key] {
            return known
        }
        if !siteLabel.isEmpty && !containsNonEnglish(siteLabel) {
            return siteLabel
        }
        return titleCased(slug: slug)
    }

    static func titleCased(slug: String) -> String {
        let words = slug
            .replacingOccurrences(of: "_", with: "-")
            .split(separator: "-")
            .map { part -> String in
                let lower = part.lowercased()
                // Keep short initialisms upper-cased (ol, ntr, 3p, pov…).
                if lower.count <= 3 && lower.rangeOfCharacter(from: .lowercaseLetters) != nil {
                    return lower.uppercased()
                }
                return lower.prefix(1).uppercased() + lower.dropFirst()
            }
        let joined = words.joined(separator: " ")
        return joined.isEmpty ? "Untitled" : joined
    }
}
