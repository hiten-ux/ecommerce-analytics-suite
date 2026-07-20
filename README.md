# ecommerce-analytics-suite
# 🛒 E-Commerce Business Intelligence Suite

> **MySQL Analytics Project** — Turning raw transactional data into actionable business insights.

---

## 📌 Project Overview

This project simulates a real-world e-commerce database (`customers`, `orders`, `products`, `categories`) and builds a **complete analytics layer** using only MySQL. No BI tools—just pure SQL.

The goal? Answer the **10 most critical questions** a CEO, CFO, and Operations Head would ask to run their business profitably.

---

## 📄 Presentation

[Click here to view/download the Portfolio Presentation PDF](https://github.com/hiten-ux/ecommerce-analytics-suite/blob/main/Hiten_Solanki_BI_Portfolio_Presentation.pdf)

---

## 🎯 Business Problems Solved

| Area | Problem Solved |
| :--- | :--- |
| 💰 **Revenue & Ops** | Tracked monthly realised revenue vs. gross order value. Identified a **40%+ Q4 seasonality spike**. |
| 👤 **Customer Health** | Built an **RFM segmentation model** (Champions, Loyal, At-Risk, Lost customers). |
| 📈 **Cohort Retention** | Calculated revenue per customer by signup month to measure long-term CLV. |
| 🏷️ **Product Performance** | Ran **ABC classification** (Pareto 80-20 rule) to find top revenue drivers. |
| ⚠️ **Inventory Risk** | Flagged products with **critical low stock (< 50 units)** and high demand-to-stock ratios. |
| 💸 **Operational Loss** | Quantified revenue **lost to cancellations/returns** and identified high-risk products. |

---

## 🛠️ Tools & Technologies

![MySQL](https://img.shields.io/badge/MySQL-8.0-4479A1?style=flat&logo=mysql&logoColor=white)
![Git](https://img.shields.io/badge/Git-F05032?style=flat&logo=git&logoColor=white)
![GitHub](https://img.shields.io/badge/GitHub-181717?style=flat&logo=github&logoColor=white)

- **MySQL** – Views, CTEs, Window Functions (`ROW_NUMBER`, `LAG`, `NTILE`), Subqueries.
- **Git & GitHub** – Version control and portfolio hosting.

---

## 🧠 Key Analytical Techniques Demonstrated

- 📊 **RFM Segmentation** (Recency, Frequency, Monetary) using `NTILE(4)` scoring.
- 📅 **Cohort Retention Analysis** – Month-over-month revenue per customer.
- 📈 **Cumulative Revenue & MoM Growth** – Using `LAG` with Window Functions.
- 🏷️ **ABC Product Classification** – Pareto (80/20) rule for inventory prioritization.
- ⚡ **Inventory Risk Modeling** – Demand-to-stock ratio to prevent stockouts.
- 🔍 **Data Cleansing** – Filtering out `Cancelled`/`Returned` orders for realised revenue.
- 🧮 **Financial Impact Analysis** – Quantifying revenue leakage from bad orders.

---

## 🗂️ Database Schema

The database consists of **4 normalized tables**:

- `customers` (1,000+ records)
- `products` (500 records)
- `categories` (50 records)
- `orders` (1,000+ records with statuses: `Delivered`, `Shipped`, `Processing`, `Cancelled`, `Returned`)

> *(ER diagram available in the `/docs` folder.)*

---

## 🚀 How to Run This Project

1. **Clone this repository** to your local machine.
2. Run `database/00_schema_and_data.sql` in MySQL Workbench to create the database and tables.
3. Run `analysis/01_business_intelligence.sql` to generate all analytical views and reports.
4. Query any view directly, e.g.:
   ```sql
   SELECT * FROM v_executive_dashboard;
   SELECT * FROM v_clv_by_cohort;
   SELECT * FROM v_product_abc_classification;
