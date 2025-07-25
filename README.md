# ⚡ GridShare – Peer-to-Peer Renewable Energy Trading Platform

**Aligns with:**

* **SDG 7**: Affordable and Clean Energy
* **SDG 11**: Sustainable Cities and Communities

**GridShare** is a decentralized smart contract platform that enables **peer-to-peer trading of renewable energy**, allowing **prosumers** (producers + consumers) to sell excess energy directly to their community.

---

## 🌞 Overview

GridShare empowers individuals and small producers to:

* Report energy generation and receive **green certificates**
* List surplus energy for sale to other users
* Accept **bids** or allow direct **buy-now** purchases
* Track **zone-level consumption and pricing statistics**
* Retire certificates to boost **green reputation**

---

## 🔌 Key Features

### 🧑‍🌾 Prosumers

* Register with solar capacity and zone
* Track energy generated, consumed, and net balance
* Earn green score for environmental contribution

### 🏷️ Energy Listings & Trading

* List surplus energy with custom price and duration
* Sell directly or via buyer bids
* Automatically updates net positions after trade

### 🟢 Green Certificates

* Issued when energy is reported/generated
* Can be retired to improve user’s green score
* Certificates include energy amount, source type, and timestamp

### 🗺️ Zone Statistics

* Each zone tracks:

  * Total generation and consumption
  * Number of prosumers
  * Average trading price

---

## 🧠 Core Data Structures

### ✅ Maps

| Name                 | Description                                                         |
| -------------------- | ------------------------------------------------------------------- |
| `prosumers`          | Info on each registered user (generation, consumption, score, etc.) |
| `energy-listings`    | Active listings of surplus energy (seller, amount, price, duration) |
| `energy-bids`        | Bids placed by buyers on specific listings                          |
| `green-certificates` | Records of verified renewable generation by a user                  |
| `zone-statistics`    | Aggregated data for each location zone                              |

### 🔢 Counters

* `listing-counter`: Unique ID tracker for listings
* `bid-counter`: Unique ID tracker for bids
* `green-certificates-issued`: Count of certificates issued
* `total-energy-traded`: Sum of all energy (kWh) traded

---

## 📦 Functionality Overview

### 🛠️ Registration & Generation

* `register-prosumer(solar-capacity, zone)`
* `report-generation(amount-kwh)`

  * Automatically issues green certificates

### ⚙️ Energy Trading

#### Sell

* `list-energy(amount-kwh, price, hours, type)`

#### Buy

* `buy-direct(listing-id, amount-kwh)`
* `place-bid(listing-id, amount-kwh, price)`
* `accept-bid(bid-id)`

### 🟩 Certificate Management

* `retire-green-certificate(certificate-id)`

---

## 📊 Read-Only Functions

| Function                         | Description                              |
| -------------------------------- | ---------------------------------------- |
| `get-prosumer-info(user)`        | Get prosumer's energy and score info     |
| `get-listing(listing-id)`        | Get details of an energy listing         |
| `get-zone-stats(zone)`           | See aggregate data per location          |
| `get-current-energy-price(zone)` | Dynamic price (peak/off-peak adjustment) |

---

## ⚠️ Error Codes

| Code   | Meaning             |
| ------ | ------------------- |
| `u100` | Owner-only function |
| `u101` | Not found           |
| `u102` | Unauthorized        |
| `u103` | Invalid amount      |
| `u104` | Insufficient energy |
| `u105` | Already exists      |
| `u106` | Bid too low         |
| `u107` | Listing not active  |

---

## 🔁 Energy Trade Flow

1. **Prosumer** registers and reports energy generation.
2. Platform issues a **green certificate**.
3. Prosumer lists energy with price and availability.
4. Buyers **bid** or **buy directly**.
5. Upon acceptance, STX is transferred, balances update, and listing is reduced/closed.
6. Users may **retire certificates** to increase green score.

---

## 💡 Smart Design

* **Peak pricing** dynamically increases costs during high-demand hours.
* **Zone stats** influence localized energy pricing.
* **Green score** encourages certificate retirement and renewable contribution.

---

## 🔐 Governance & Parameters

* Base energy price and peak-hour multiplier are set via `data-vars`:

  * `base-energy-price`: 1 STX = 1000 microSTX/kWh (default)
  * `peak-hour-multiplier`: 1.5x during peak (e.g., 17–21h)

---

## 📈 Sustainable Development Goals Impact

| SDG        | Contribution                                                        |
| ---------- | ------------------------------------------------------------------- |
| **SDG 7**  | Expands access to clean, locally sourced energy via peer trade      |
| **SDG 11** | Encourages community-based sustainability and grid decentralization |

---

## 📝 License

This contract is released under the **MIT License** and open to contribution.
