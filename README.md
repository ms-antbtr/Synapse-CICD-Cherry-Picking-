# Synapse-CICD-Cherry-Picking-

The idea of this solution is to overcome a challenge that many developers will face when they want to promote one project artifact from one environment to another i.e. UAT to Pre-prod. 

If we take a scenario whereby in Azure Synapse you have a number of artifacts such as:

- Pipelines
- Spark Job Definitions
- SQLScripts
- Linked Services 

And you wanted to promote a single artifact such as 1 Pipeline from a UAT Synase to a Pre-prod Synapse environment; currently what you will have to do is promote ALL pipelines.

With this solution explained below; what you have the ability in doing is promoting single artifacts such as a single pipeline from environments. Additionally you have the ability to enter key words / names for this migration to occur.

![image](https://user-images.githubusercontent.com/72390693/169803148-dff5c15f-fbd0-4403-a99a-e0c854a4acde.png)


# The following steps sets out how to implement the solution
