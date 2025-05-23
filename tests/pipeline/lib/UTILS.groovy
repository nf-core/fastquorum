// Function to remove Nextflow version from software_versions.yml

class UTILS {
    public static String removeNextflowVersion(outputDir) {
        def softwareVersions = path("$outputDir/pipeline_info/nf_core_fastquorum_software_mqc_versions.yml").yaml
        if (softwareVersions.containsKey("Workflow")) {
            softwareVersions.Workflow.remove("Nextflow")
        }
        return softwareVersions
    }
}
