# Notes for debugging the Glance Operator

## Development Cycle

The [glance_dev.sh](glance_dev.sh) is supposed to help with the following cycle.

Assuming an operator is running and you want to run a new patch...

1. delete the service as below and stop the operator (ctrl-c)
   ```
   ls ~/install_yamls/out/openstack/glance/cr
   oc delete -f ~/install_yamls/out/openstack/glance/cr/glance_v1beta1_glance.yaml
   ```

2. delete the crds:
   ```
   for CRD in $(oc get crds | grep -i glance | awk {'print $1'}); do
        oc delete crds $CRD;
   done
   ```

3. run the new operator and recreate the new crds
   ```
   cd  ~/install_yamls/develop_operator/glance-operator
   make generate && make manifests && make build
   MET_PORT=6666
   OPERATOR_TEMPLATES=$PWD/templates ./bin/manager -metrics-bind-address ":$MET_PORT"
   ```

   You might observe exceptions until CRDs are created with the following.

   ```
   oc create -f ~/install_yamls/develop_operator/glance-operator/config/crd/bases/glance.openstack.org_glanceapis.yaml
   oc create -f ~/install_yamls/develop_operator/glance-operator/config/crd/bases/glance.openstack.org_glances.yaml
   ```

4. redeploy
   ```
   oc kustomize ~/install_yamls/out/openstack/glance/cr | oc apply -f -
   ```

If you need to modify lib-common see [local-lib-common.md](local-lib-common.md).

## Deleting resources to unblock creating new ones

The following additional cleaning commands may be necessary

```
oc delete deployment glance -n openstack
oc delete pvc glance
oc delete GlanceAPI glance
```

`oc edit pv local-storage00x` and remove the `ClaimRef`

```
for i in $(oc get pv | egrep "Failed|Released" | awk {'print $1'}); do
  oc patch pv $i --type='json' -p='[{"op": "remove", "path": "/spec/claimRef"}]';
done
```

Edit the CRD (`oc edit crd`) and remove
[finalizers](https://kubernetes.io/blog/2021/05/14/using-finalizers-to-control-deletion/)
(`- finalizers:`) which might be blocking deletion.

## Example: Apply Glance Operator Change

If you have the Glance operator running and want to switch from its
default file backend to its Ceph backend:

- Create a Ceph secret: [ceph_secret.sh](cr/ceph_secret.sh)
- oc create -f [glance_v1beta1_ceph_secret.yaml](cr/glance_v1beta1_ceph_secret.yaml)

```
cp cr/glance_v1beta1_ceph_secret.yaml ~/install_yamls/out/openstack/glance/cr/glance_v1beta1_glance.yaml
oc delete -f ~/install_yamls/out/openstack/glance/cr/glance_v1beta1_glance.yaml
oc kustomize ~/install_yamls/out/openstack/glance/cr | oc apply -f -
```
