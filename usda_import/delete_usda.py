"""
Delete all USDA-imported businesses from Firestore
Helper to run before re-importing with updated fields
"""

import firebase_admin
from firebase_admin import credentials, firestore

FIREBASE_SERVICE_ACCOUNT_PATH = "food-oasis-fbab6-firebase-adminsdk-fbsvc-74a81df343.json"

# Initialize Firebase
cred = credentials.Certificate(FIREBASE_SERVICE_ACCOUNT_PATH)
firebase_admin.initialize_app(cred)
db = firestore.client()

def main():
    print("Finding all USDA businesses...")
    
    docs = db.collection("businesses").where("source", "==", "USDA").get()
    
    print(f"Found {len(docs)} USDA businesses to delete")
    
    if len(docs) == 0:
        print("Nothing to delete!")
        return
    
    confirm = input("Are you sure you want to delete these? (yes/no): ")
    
    if confirm.lower() != "yes":
        print("Cancelled.")
        return
    
    deleted = 0
    for doc in docs:
        doc.reference.delete()
        deleted += 1
        print(f"Deleted: {doc.to_dict().get('name', 'Unknown')[:50]}")
    
    print(f"\nDeleted {deleted} businesses")

if __name__ == "__main__":
    main()
