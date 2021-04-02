#!/bin/bash
mkdir webmocks
cd webmocks
mkdir criminalnotebook
cd ..

for item in List_of_Summary_Conviction_Offences List_of_Straight_Indictable_Offences List_of_Hybrid_Offences Miscellaneous_Offences_Against_Public_Order
do
  HTTP_CODE=$(curl --write-out "%{http_code}\n Processing $item " "http://criminalnotebook.ca/index.php/$item" --output webmocks/criminalnotebook/$item.html )
  echo $HTTP_CODE
done
