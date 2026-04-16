# BoatNav — App Store Connect + RevenueCat Handoff

Opdracht voor Claude Desktop:
**Vul App Store Connect en RevenueCat in op basis van onderstaande info. Beide staan open in Chrome. Gebruik computer use om tabbladen te openen, formulieren te vullen, en knoppen te klikken. Stop voordat je daadwerkelijk iets "submit" of "publish" — vraag daar eerst bevestiging voor.**

---

## 1. Projectidentiteit

| Veld | Waarde |
|---|---|
| App-naam | **BoatNav** |
| Bundle ID | `nl.boatnav.app` |
| SKU (App Store Connect intern) | `boatnav-ios-v1` |
| Apple Team ID | `3TZFTAC2SR` |
| Primaire taal | Dutch (Netherlands) |
| Beschikbaarheid | Nederland (of wereldwijd — user beslist) |
| Prijsmodel | Free + in-app purchases |
| Platform | iOS only (iPhone) |
| Minimum iOS | 17.0 |
| Swift / Xcode | Swift 5.9 / Xcode 16.0 |
| Versie | 1.0 (build 1) |

---

## 2. App Store Connect — stap voor stap

### Stap A: My Apps → "+" → New App

- **Platforms:** iOS
- **Name:** BoatNav
- **Primary Language:** Dutch (Netherlands)
- **Bundle ID:** selecteer `nl.boatnav.app` uit de dropdown (moet eerst in Apple Developer → Identifiers bestaan — zie sectie 5)
- **SKU:** `boatnav-ios-v1`
- **User Access:** Full Access

### Stap B: App Information → General

- **Subtitle (30 chars max):** `Navigatie voor vaarwegen`
- **Primary Category:** Navigation
- **Secondary Category:** Travel
- **Content Rights:** "Does not contain, show, or access third-party content"
- **Age Rating:** 4+ (geen beperkende content)

### Stap C: Pricing and Availability

- **Price Tier:** Free
- **Availability:** Netherlands (uitbreiden naar Belgium + EU als user dat wil)

### Stap D: App Privacy (Data Collection)

Klik op **"Get Started"** en selecteer deze data types:

**Location → Precise Location**
- Linked to user identity: NO (tenzij CloudKit friend sharing aan staat — dan YES)
- Used for tracking: NO
- Purpose: **App Functionality** (navigation, GPS speed)

**Purchases → Purchase History**
- Linked to user identity: YES
- Used for tracking: NO
- Purpose: **App Functionality** (RevenueCat subscription management)

**User Content → Other User Content** (hazard reports en friend locations via CloudKit)
- Linked to user identity: YES
- Used for tracking: NO
- Purpose: **App Functionality**

**Identifiers → User ID** (CloudKit user record ID)
- Linked to user identity: YES
- Used for tracking: NO
- Purpose: **App Functionality**

### Stap E: Version 1.0 → Prepare for Submission

**Promotional Text** (optioneel, 170 chars max):
```
Vaar slim met actuele waterkaarten, brughoogtes en snelheidslimieten. Meld obstakels en deel je locatie met vrienden.
```

**Description:**
```
BoatNav is dé navigatie-app voor Nederlandse binnenwateren. Actuele waterkaarten van PDOK en OpenSeaMap, brughoogte-waarschuwingen, snelheidslimieten per vaarweg, en realtime weer.

FUNCTIES
• Waterkaart met boeien, bakens en dieptecontouren
• Route-navigatie tussen havens, sluizen en bruggen
• GPS-snelheid in km/h en knopen
• Brughoogte- en diepgangwaarschuwingen op basis van je bootprofiel
• Weer met windsterkte, beaufort en neerslag
• Meldingen delen: politie, drijvend vuil, ondiepte, kapotte betonning, waterplanten
• Locatie delen met vrienden via een persoonlijke code
• Sluis- en brughoogtes op de kaart

BOATNAV PRO
Upgrade naar Pro voor:
• Route-navigatie tussen waypoints
• Onbeperkt favorieten en opgeslagen routes
• Brughoogte-waarschuwingen op basis van je bootprofiel
• Uitbreidingen voor serieuze vaarders

DATA
Kaartdata van PDOK (Rijkswaterstaat binnenwateren) en OpenSeaMap. Realtime weer via Open-Meteo. Meldingen en vriendenlocaties worden versleuteld opgeslagen via Apple CloudKit.

Gebruik BoatNav niet als vervanging voor officiële vaarkaarten.
```

**Keywords** (100 chars max, kommagescheiden):
```
bootnavigatie,vaarweg,waterkaart,binnenwater,sluis,brug,GPS,knopen,vaarroute,boot,haven,zeilen
```

**Support URL:** `https://boatnav.nl/support` *(CHECK: heeft user deze URL? Zo niet, gebruik een mailto of GitHub issues)*

**Marketing URL:** leeg laten of `https://boatnav.nl`

**Copyright:** `© 2026 Harm Rietmeijer`

**Version Release:** Automatically release this version

**App Review Information:**
- Contact first name + last name: (user vragen)
- Phone: (user vragen)
- Email: (user vragen)
- Demo account: *NIET van toepassing — geen login vereist*
- Notes: 
```
BoatNav is a navigation app for Dutch inland waterways. No login required.
Test hazard reporting: tap the orange hazard button (left side, above map).
Test location sharing: open Friends panel via map buttons.
Test in-app purchase: Settings → Upgrade to Pro. Use sandbox account.
Waterway data is fetched from PDOK (Dutch government open data).
```

**Version Release Notes** (What's New — voor toekomstige versies, nu leeg/niet van toepassing voor 1.0):
```
Eerste release van BoatNav. Navigeer op Nederlandse binnenwateren met actuele waterkaarten.
```

### Stap F: Build

*(Build upload gebeurt via Xcode of Fastlane, niet via de web-UI. Deze stap overslaan in Claude Desktop.)*

### Stap G: In-App Purchases aanmaken

Ga naar **Features → In-App Purchases → "+"**

**Purchase 1:**
- Type: **Auto-Renewable Subscription**
- Reference Name: `BoatNav Pro Yearly`
- Product ID: `nl.boatnav.app.pro.yearly`
- Subscription Group: nieuwe groep `Pro`
- Subscription Duration: 1 Year
- Price: €29.99 (Tier 30)
- Display Name (NL): `Jaarabonnement`
- Description (NL): `Volledige Pro-toegang voor een jaar. Automatisch verlengd tenzij opgezegd.`
- **Free Trial:** 7 days introductory offer

**Purchase 2:**
- Type: **Non-Consumable**
- Reference Name: `BoatNav Pro Lifetime`
- Product ID: `nl.boatnav.app.pro.lifetime`
- Price: €79.99 (Tier 80)
- Display Name (NL): `Lifetime`
- Description (NL): `Eenmalige aankoop voor permanente Pro-toegang.`

---

## 3. RevenueCat — stap voor stap

### Stap A: Projects → "+ New project"

- **Project name:** BoatNav

### Stap B: Add app

- **Platform:** iOS / App Store
- **App name:** BoatNav iOS
- **App Bundle ID:** `nl.boatnav.app`
- **App Store Connect Shared Secret:** (user moet deze kopiëren uit App Store Connect → Users and Access → Integrations → App-Specific Shared Secret → Generate)

### Stap C: API Keys

Genereer een **public iOS API key** (begint met `appl_...`) en kopieer. Deze komt later in de app-code (zie sectie 6).

### Stap D: Products

Klik **Products → "+ New"** en voeg de twee product IDs toe die in stap G in App Store Connect zijn aangemaakt:
- `nl.boatnav.app.pro.yearly`
- `nl.boatnav.app.pro.lifetime`

### Stap E: Entitlements

Ga naar **Entitlements → "+ New"**:
- Identifier: **`BoatNav Pro`** ⚠️ Exact deze string — de app-code verwijst hiernaar (zie `SubscriptionManager.swift:14`)
- Attach products: beide products uit Stap D

### Stap F: Offerings

Klik **Offerings → "+ New"**:
- Identifier: `default`
- **Make this the current offering:** yes
- Packages:
  - Package ID `$rc_annual` → attach product `nl.boatnav.app.pro.yearly`
  - Package ID `$rc_lifetime` → attach product `nl.boatnav.app.pro.lifetime`

### Stap G: Apple Server-to-Server Notifications

RevenueCat toont een URL (lijkt op `https://api.revenuecat.com/v1/incoming/apple/...`).

Ga terug naar App Store Connect:
- **App Information → App Store Server Notifications**
- Paste de URL in **Production Server URL** én **Sandbox Server URL**
- Version: **Version 2**

---

## 4. CloudKit — container + schema

User heeft al een CloudKit container: `iCloud.nl.boatnav.app` (gedefinieerd in `BoatNav/Resources/BoatNav.entitlements`).

Record types aanmaken in [CloudKit Dashboard](https://icloud.developer.apple.com/dashboard/):

**HazardReport** (Public database)
- reportID: String (queryable, sortable)
- category: String (queryable)
- latitude: Double
- longitude: Double
- createdAt: Date/Time (queryable, sortable)
- votes: Int64

**Friend** (Private database)
- userID: String
- displayName: String
- addedAt: Date/Time

**UserLocation** (Public database, gesharede via shareCode)
- userID: String (queryable)
- shareCode: String (queryable)
- displayName: String
- latitude: Double
- longitude: Double
- heading: Double
- lastUpdated: Date/Time (queryable, sortable)

**Security Roles:** defaults (World Read + Authenticated Write voor public, Owner only voor private).

**Deploy schema naar Production** na testen in Development environment.

---

## 5. Apple Developer — App ID configuratie (vereist vóór App Store Connect)

Als de Bundle ID `nl.boatnav.app` nog niet in de dropdown staat in Stap A: ga naar [developer.apple.com/account](https://developer.apple.com/account) → **Identifiers → "+"**.

- **Type:** App IDs → App
- **Description:** BoatNav
- **Bundle ID:** Explicit → `nl.boatnav.app`
- **Capabilities aanvinken:**
  - ✅ iCloud (met container `iCloud.nl.boatnav.app`)
  - ✅ Background Modes (location updates)
  - ✅ In-App Purchase
  - ✅ CarPlay (⚠️ vereist separate approval via https://developer.apple.com/contact/carplay/ — zonder approval werkt de CarPlay scene niet in productie)
  - ✅ Push Notifications (optioneel, voor toekomstige hazard alerts)

---

## 6. Code-aanpassing na RevenueCat setup

In `BoatNav/Services/Subscription/SubscriptionManager.swift:15` staat nu:
```swift
private let apiKey = "test_HvdoegnVXDKqJHCSJvIlgBRlzvz"
```

Vervang door de **production public iOS API key** uit RevenueCat (zie Stap C hierboven). Deze begint met `appl_...`. NIET de secret key — die is voor server-side gebruik.

---

## 7. Wat ontbreekt nog (user handmatig aanleveren)

- [ ] **App icon 1024×1024** (PNG, no alpha, square) voor App Store
- [ ] **Screenshots** 6.7" (1290×2796) en 6.5" (1242×2688) — minimaal 3, aanbevolen 6
- [ ] **Support URL** — is `https://boatnav.nl/support` actief?
- [ ] **Privacy policy URL** — verplicht voor subscriptions, moet publiek bereikbaar zijn
- [ ] **App Review contact info** (naam, telefoon, email)
- [ ] **TestFlight build** — upload via Xcode Organizer of Fastlane voordat je de app indient voor review
- [ ] **App-Specific Shared Secret** in RevenueCat (genereer in App Store Connect → Users and Access → Integrations)
- [ ] **CarPlay entitlement request** indienen bij Apple als CarPlay in v1 moet werken

---

## 8. Submit volgorde (wat eerst)

1. Apple Developer → App ID aanmaken met capabilities ✅
2. App Store Connect → App aanmaken + metadata vullen (dit document)
3. App Store Connect → In-App Purchases aanmaken (Stap G hierboven)
4. RevenueCat → Project + products + entitlements + offerings (sectie 3)
5. RevenueCat → Shared Secret toevoegen
6. App Store Connect → Server Notifications URL van RevenueCat plakken
7. Code → RevenueCat production API key invullen
8. Xcode → Archive + upload naar TestFlight
9. App Store Connect → Submit for Review (pas NADAT alles getest is in TestFlight)

---

**Einde handoff. Claude Desktop: begin bij sectie 2 (App Store Connect) tenzij user anders aangeeft. Stop voor elke "Submit" of "Release" knop en vraag bevestiging.**
