ThisBuild / scalaVersion := "2.11.12"
Test / parallelExecution := false
Global /concurrentRestrictions += Tags.limit(Tags.Test, 1)

lazy val processing = (project in file("."))
  .settings(
    name := "Data Processing",
    //coverageExcludedPackages := ".*processing.ingestion.StreamReader*;processing.spark*;processing.SchemaReader*;.*processing.Main*;.*\\.MercuryMapper",
    coverageExcludedPackages := ".*\\.spark*;.*\\.StreamReader;.*\\.StreamListener;.*\\.SchemaReader;.*\\.Main;.*\\.PipelineManager;.*\\.MercuryMapper;.*\\.Distributor;.*\\.DistributionConstants;com\\.microsoft\\.mercury\\.util.*;.*\\.ProfitCenterDistributor;.*\\.ExecutiveFunctionHierarchyDistributor;",
    Compile / mainClass := Some("processing.Main"),
    // Customize JAR file name if desired
    artifactName := { (sv: ScalaVersion, module: ModuleID, artifact: Artifact) =>
      artifact.name + "_" + sv.binary + "-" + module.revision + "." + artifact.extension // default
      // artifact.name + "_" + sv.binary + "-" + module.revision + "_" + sys.env("USERNAME") + "." + artifact.extension // Include user name
    }
  )

// Libraries provided by Azure Synapse 2.4 runtime - https://docs.microsoft.com/en-us/azure/synapse-analytics/spark/apache-spark-24-runtime
libraryDependencies ++= Seq(
  "com.microsoft.azure.synapse" %% "synapseutils" % "1.4" % "provided",
  "com.typesafe" % "config" % "1.3.4" % "provided",
  "io.delta" %% "delta-core" % "0.6.1" % "provided",
  "org.apache.commons" % "commons-lang3" % "3.5" % "provided",
  "org.apache.spark" %% "spark-sql" % "2.4.4" % "provided"
)

// Sorted alphabetically for easier reading
libraryDependencies ++= Seq(
  "com.microsoft.azure" % "applicationinsights-core" % "2.6.4",
  "com.microsoft.azure" % "azure-cosmosdb-spark_2.4.0_2.11" % "3.3.4",
  "com.microsoft.azure" % "azure-sqldb-spark" % "1.0.2",
  "com.microsoft.azure" %% "azure-eventhubs-spark" % "2.3.18",
  "joda-time" % "joda-time" % "2.10.13",
  "org.apache.hadoop" % "hadoop-azure-datalake" % "2.8.1",
  "org.rogach" %% "scallop" % "4.1.0",
  "org.scalaj" %% "scalaj-http" % "2.4.2",
)

// Test libraries
libraryDependencies ++= Seq (
  "com.holdenkarau" %% "spark-testing-base" % "2.4.3_0.12.0" % "test",
  "org.mockito" % "mockito-core" % "2.9.0" % "test",
  "org.scalatest" %% "scalatest" % "3.0.8" % "test",
)

dependencyOverrides ++= Seq(
  "com.fasterxml.jackson.core" % "jackson-core" % "2.6.7",
  "com.fasterxml.jackson.core" % "jackson-databind" % "2.6.7",
  "com.fasterxml.jackson.module" % "jackson-module-scala_2.11" % "2.6.7",
)

