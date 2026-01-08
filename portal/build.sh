#/bin/sh

VER=0.3.0
IMAGE=decoacr.azurecr.io/centuryply_inventory_management_portal:$VER-amd

docker build . --platform linux/amd64 -t $IMAGE && docker push $IMAGE

az containerapp update \
    --name deco-1 \
    --resource-group Deco-App \
    --image decoacr.azurecr.io/centuryply_inventory_management_portal:0.3.0-amd