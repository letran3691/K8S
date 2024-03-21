Granting access to users

    kubectl get clusterroles

note: ClusterRoleBindings grant a user, group, or service account a ClusterRole’s power across the entire cluster. Using kubectl, we can let a sample user “jane” perform basic actions in all namespaces by binding her to the “edit” ClusterRole:

    kubectl create clusterrolebinding trunglv --clusterrole=edit --user=trunglv


refer: https://kubernetes.io/blog/2017/10/using-rbac-generally-available-18/

