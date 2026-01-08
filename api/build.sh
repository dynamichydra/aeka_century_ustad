#/bin/sh

VER=0.3.1
IMAGE=decoacr.azurecr.io/centuryply_inventory_management_api:$VER-amd

docker build . --platform linux/amd64 -t $IMAGE && docker push $IMAGE


# az containerapp update \
#     --name deco-2 \
#     --resource-group Deco-App \
#     --image decoacr.azurecr.io/centuryply_inventory_management_api:0.3.1-amd