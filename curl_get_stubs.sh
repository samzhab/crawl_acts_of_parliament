#!/bin/bash
for item in A B C D E F G H I J K L M N O P Q R S T U V W X Y Z
do
  HTTP_CODE=$(curl --write-out "%{http_code}\n Processing $item " "https://laws-lois.justice.gc.ca/eng/acts/$item.html" --output webmocks/$item.html )
  echo $HTTP_CODE
done
