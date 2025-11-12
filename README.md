# Laser Shop Sales Database (PostgreSQL)

## Overview
A simple PostgreSQL database to track custom CO₂-laser product sales, orders, and payments.  
Built to meet all CSE 310 SQL Relational Database module 1 requirements.

### Tables
- `customers` — Stores customer info
- `products` — Laser-engraved items for sale
- `orders` — Tracks customer orders
- `order_items` — Products per order
- `payments` — Records order payments

### Demonstrated Features Completed
Created database and tables  
Set up CRUD operations (insert, update, delete, select)  
Multiple-table joins  
Aggregate functions (SUM, GROUP BY)  
Date filtering with `BETWEEN` and `interval`  
PostgreSQL JSONB field for product specs

### Example Queries
- Orders and totals per customer  
- Payments vs balances  
- Monthly revenue  
- Top-selling products  

### Setup
1. Create the database in pgAdmin:  
   `CREATE DATABASE laser_shop;`
2. Run `laserDB-TableCreation.sql` to create tables  
3. Run `laserDB-SeedData.sql` to insert sample data  
4. Run `queries.sql` to test queries
5. Edit / Run `laserDB-CRUD.sql` for CRUD operations 

### Video Demo Link
https://youtu.be/IyQiT2pHnh0 

---
