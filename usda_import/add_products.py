"""
Populate sample products for a business in Firestore
"""

import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime

# ============== CONFIGURATION ==============
FIREBASE_SERVICE_ACCOUNT_PATH = "food-oasis-fbab6-firebase-adminsdk-fbsvc-74a81df343.json"

# Your business info
BUSINESS_ID = "ld47feX89WWygeVHXhVR"
OWNER_UID = "NhT6Nt4vm8VG0UiR3huD64zBved2"

# ============================================

# Initialize Firebase
cred = credentials.Certificate(FIREBASE_SERVICE_ACCOUNT_PATH)
firebase_admin.initialize_app(cred)
db = firestore.client()

# Sample products to add
SAMPLE_PRODUCTS = [
    {
        "name": "Organic Apples",
        "description": "Fresh, locally grown organic apples. Crisp and sweet.",
        "price": 3.99,
        "quantity": 50,
        "unit": "lb",
        "category": "Fruits",
    },
    {
        "name": "Fresh Kale Bunch",
        "description": "Organic green kale, perfect for smoothies or salads.",
        "price": 2.49,
        "quantity": 30,
        "unit": "bunch",
        "category": "Vegetables",
    },
    {
        "name": "Farm Fresh Eggs",
        "description": "Dozen pasture-raised eggs from local farms.",
        "price": 5.49,
        "quantity": 25,
        "unit": "dozen",
        "category": "Dairy",
    },
    {
        "name": "Raw Honey",
        "description": "Pure, unfiltered local honey from Georgia bees.",
        "price": 12.99,
        "quantity": 20,
        "unit": "jar",
        "category": "Baked Goods",
    },
    {
        "name": "Organic Carrots",
        "description": "Sweet and crunchy carrots, locally sourced.",
        "price": 1.99,
        "quantity": 40,
        "unit": "lb",
        "category": "Vegetables",
    },
    {
        "name": "Fresh Squeezed Orange Juice",
        "description": "Made fresh daily with Florida oranges.",
        "price": 6.99,
        "quantity": 15,
        "unit": "bottle",
        "category": "Drinks",
    },
    {
        "name": "Vegan Buddha Bowl",
        "description": "Protein-packed bowl with quinoa, chickpeas, and fresh vegetables.",
        "price": 12.99,
        "quantity": 10,
        "unit": "bowl",
        "category": "Vegan",
    },
    {
        "name": "Sourdough Bread",
        "description": "Freshly baked whole grain sourdough loaf.",
        "price": 7.99,
        "quantity": 12,
        "unit": "loaf",
        "category": "Baked Goods",
    },
]


def main():
    print("=" * 50)
    print("Adding Products to Firestore")
    print("=" * 50)
    print(f"Business ID: {BUSINESS_ID}")
    print(f"Owner UID: {OWNER_UID}")
    print()

    added = 0

    for product in SAMPLE_PRODUCTS:
        try:
            doc_data = {
                "name": product["name"],
                "description": product["description"],
                "price": product["price"],
                "quantity": product["quantity"],
                "unit": product["unit"],
                "category": product["category"],
                "businessId": BUSINESS_ID,
                "ownerUid": OWNER_UID,
                "createdAt": firestore.SERVER_TIMESTAMP,
            }

            db.collection("products").add(doc_data)
            print(f"++ Added: {product['name']}")
            added += 1

        except Exception as e:
            print(f"!! Failed: {product['name']} - {e}")

    print()
    print("=" * 50)
    print(f"Done! Added {added} products.")
    print("=" * 50)


if __name__ == "__main__":
    main()
