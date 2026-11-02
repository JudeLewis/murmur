import Foundation

/// Turns American spellings into British ones ("color" to "colour").
///
/// The speech models learned mostly from American text, so they spell that way.
/// This works from a fixed list of whole words rather than rules, because rules
/// break real words: "size" and "prize" must not become "sise" and "prise".
/// Words spelt the same in both, or that change with meaning (program, license,
/// check, tire, meter), are left alone.
public enum BritishSpelling {
    public static func apply(to text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: "[A-Za-z]+") else { return text }
        let source = text as NSString
        var result = ""
        var last = 0
        for match in regex.matches(in: text, range: NSRange(location: 0, length: source.length)) {
            let word = source.substring(with: match.range)
            guard let british = table[word.lowercased()] else { continue }
            result += source.substring(with: NSRange(location: last, length: match.range.location - last))
            result += matchCase(of: word, to: british)
            last = match.range.location + match.range.length
        }
        result += source.substring(from: last)
        return result
    }

    /// "Color" becomes "Colour" and "COLOR" becomes "COLOUR".
    static func matchCase(of original: String, to replacement: String) -> String {
        if original.count > 1, original == original.uppercased() { return replacement.uppercased() }
        if original.first?.isUppercase == true { return replacement.prefix(1).uppercased() + replacement.dropFirst() }
        return replacement
    }

    /// Lower-case American spelling to British spelling.
    static let table: [String: String] = {
        var table: [String: String] = [:]

        // -ize to -ise, with the forms that follow the same pattern.
        let izeStems = [
            "agon", "antagon", "apolog", "author", "brutal", "capital", "categor", "central",
            "character", "civil", "colon", "commercial", "computer", "critic", "crystall", "custom",
            "decentral", "democrat", "demon", "desensit", "destabil", "digit", "dramat", "econom",
            "emphas", "empath", "energ", "equal", "eulog", "external", "familiar", "fantas",
            "fertil", "final", "formal", "fossil", "general", "global", "harmon", "hospital",
            "human", "hypnot", "hypothes", "ideal", "immun", "incentiv", "industrial", "initial",
            "internal", "item", "jeopard", "legal", "legitim", "liberal", "local", "magnet",
            "marginal", "material", "maxim", "memor", "mesmer", "metabol", "miniatur", "minim",
            "mobil", "modern", "monet", "monopol", "moral", "motor", "national", "natural",
            "neutral", "normal", "optim", "organ", "ostrac", "oxid", "patron", "penal",
            "personal", "polar", "popular", "pressur", "priorit", "privat", "public", "radical",
            "random", "rational", "real", "recogn", "reorgan", "revital", "revolution", "romantic",
            "sanit", "satir", "scandal", "scrutin", "sensational", "serial", "social", "special",
            "stabil", "standard", "steril", "stigmat", "strateg", "subsid", "summar", "symbol",
            "sympath", "synchron", "synthes", "tantal", "terror", "theor", "trivial", "tyrann",
            "urban", "util", "vandal", "victim", "visual", "vocal",
        ]
        let izeEndings = [
            ("ize", "ise"), ("izes", "ises"), ("ized", "ised"), ("izing", "ising"),
            ("izer", "iser"), ("izers", "isers"), ("ization", "isation"), ("izations", "isations"),
        ]
        for stem in izeStems {
            for (us, uk) in izeEndings { table[stem + us] = stem + uk }
        }

        // -yze to -yse.
        for stem in ["anal", "catal", "paral", "breathal", "electrol"] {
            for (us, uk) in [("yze", "yse"), ("yzes", "yses"), ("yzed", "ysed"), ("yzing", "ysing"),
                             ("yzer", "yser"), ("yzers", "ysers")] {
                table[stem + us] = stem + uk
            }
        }

        // -or to -our. Only these endings: "humorous", "honorary", "laborious",
        // "vigorous" and "glamorous" are the same in British English.
        let ourStems = [
            "ard", "arm", "behavi", "cand", "clam", "col", "demean", "endeav", "fav",
            "ferv", "flav", "harb", "hon", "hum", "lab", "neighb", "od", "parl", "ranc",
            "rum", "sav", "splend", "tum", "val", "vap", "vig",
        ]
        let ourEndings = [
            "", "s", "ed", "ing", "ful", "fully", "less", "able", "ably", "ite", "ites",
            "hood", "hoods", "ly", "er", "ers", "al", "ally", "y",
        ]
        for stem in ourStems {
            for ending in ourEndings {
                table[stem + "or" + ending] = stem + "our" + ending
            }
        }
        // Forms the endings above make that are wrong or are real words of their own.
        for word in ["honorary", "odorous", "humoral", "valorous", "colorist", "armorial", "favorer"] {
            table[word] = nil
        }
        table["humorous"] = nil
        table["savior"] = "saviour"
        table["saviors"] = "saviours"
        table["glamor"] = "glamour"

        // -er to -re.
        let reWords: [String: String] = [
            "center": "centre", "centers": "centres", "centered": "centred", "centering": "centring",
            "centerpiece": "centrepiece", "centerpieces": "centrepieces",
            "theater": "theatre", "theaters": "theatres", "fiber": "fibre", "fibers": "fibres",
            "fiberglass": "fibreglass", "liter": "litre", "liters": "litres",
            "milliliter": "millilitre", "milliliters": "millilitres", "caliber": "calibre",
            "somber": "sombre", "saber": "sabre", "specter": "spectre", "luster": "lustre",
            "meager": "meagre", "kilometer": "kilometre", "kilometers": "kilometres",
            "centimeter": "centimetre", "centimeters": "centimetres",
            "millimeter": "millimetre", "millimeters": "millimetres",
        ]
        table.merge(reWords) { _, new in new }

        // Doubled l before -ed, -ing, -er.
        let lStems = [
            "cancel", "channel", "counsel", "dial", "duel", "equal", "fuel", "funnel", "grovel",
            "label", "level", "libel", "marvel", "model", "panel", "pedal", "quarrel", "rival",
            "shovel", "signal", "snorkel", "swivel", "total", "towel", "travel", "tunnel",
            "unravel", "yodel", "worship",
        ]
        for stem in lStems {
            let doubled = stem.hasSuffix("p") ? stem + "p" : stem + "l"
            table[stem + "ed"] = doubled + "ed"
            table[stem + "ing"] = doubled + "ing"
        }
        table["traveler"] = "traveller"
        table["travelers"] = "travellers"
        table["counselor"] = "counsellor"
        table["counselors"] = "counsellors"
        table["jeweler"] = "jeweller"
        table["jewelers"] = "jewellers"
        table["jewelry"] = "jewellery"
        table["marvelous"] = "marvellous"
        table["marvelously"] = "marvellously"
        table["woolen"] = "woollen"

        // Everything else.
        let others: [String: String] = [
            "aluminum": "aluminium", "airplane": "aeroplane", "airplanes": "aeroplanes",
            "analog": "analogue", "anemia": "anaemia", "anesthetic": "anaesthetic",
            "artifact": "artefact", "artifacts": "artefacts",
            "catalog": "catalogue", "catalogs": "catalogues", "cozy": "cosy",
            "defense": "defence", "defenses": "defences", "dialog": "dialogue", "dialogs": "dialogues",
            "enroll": "enrol", "enrollment": "enrolment", "enrollments": "enrolments",
            "esthetic": "aesthetic", "fulfill": "fulfil", "fulfillment": "fulfilment",
            "gray": "grey", "grays": "greys", "grayish": "greyish",
            "installment": "instalment", "installments": "instalments",
            "mold": "mould", "molds": "moulds", "moldy": "mouldy", "molded": "moulded",
            "mom": "mum", "moms": "mums", "mommy": "mummy",
            "maneuver": "manoeuvre", "maneuvers": "manoeuvres", "maneuvered": "manoeuvred",
            "maneuvering": "manoeuvring", "mustache": "moustache", "offense": "offence",
            "offenses": "offences", "omelet": "omelette", "omelets": "omelettes",
            "pajamas": "pyjamas", "pediatric": "paediatric", "pediatrician": "paediatrician",
            "plow": "plough", "pretense": "pretence", "skeptic": "sceptic",
            "skeptical": "sceptical", "skepticism": "scepticism", "skillful": "skilful",
            "skillfully": "skilfully", "sulfur": "sulphur", "willful": "wilful",
        ]
        table.merge(others) { _, new in new }
        return table
    }()
}
