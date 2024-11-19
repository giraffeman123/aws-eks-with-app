resource "helm_release" "merge_sort_chart" {
  name             = "merge-sort"
  chart            = "/home/kaliadmin/Documents/Software Projects/aws/aws-eks/modules/merge-sort-api/merge-sort-chart"
  create_namespace = true
  namespace        = var.namespace

  values = [templatefile("${path.module}/merge-sort-chart/values.yaml", {
    image_name     = "elliotmtz12/merge-sort"
    container_port = "8080"
    namespace      = var.namespace
  })]
}