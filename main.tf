resource "azurerm_resource_group" "this" {
    name     = "testrg"
    location = "japaneast"
}

# [Preview]: Storage account public access should be disallowed
# az role definition list --name "Contributor"
# az role definition list --name "Storage Account Contributor"
# az role definition list --name "Storage Blob Data Contributor"
resource "azurerm_policy_definition" "policy" {
  name         = "[Custom] Storage account public access should be disallowed"
  policy_type  = "Custom"
  mode         = "All"
  display_name = "[Custom] Storage account public access should be disallowed"

  metadata = <<METADATA
{
  "category": "Storage"
}
METADATA

  policy_rule = <<POLICY_RULE
{
  "if": {
    "allOf": [
      {
        "field": "type",
        "equals": "Microsoft.Storage/storageAccounts"
      },
      {
        "not": {
          "allOf": [
            {
              "field": "id",
              "contains": "/resourceGroups/aro-"
            },
            {
              "anyOf": [
                {
                  "field": "name",
                  "like": "cluster*"
                },
                {
                  "field": "name",
                  "like": "imageregistry*"
                }
              ]
            }
          ]
        }
      },
      {
        "not": {
          "field": "Microsoft.Storage/storageAccounts/allowBlobPublicAccess",
          "equals": "false"
        }
      }
    ]
  },
  "then": {
    "effect": "[parameters('effect')]",
    "details": {
      "type": "Microsoft.Storage/storageAccounts",
      "roleDefinitionIds": [
        "${data.azurerm_role_definition.definition1.id}",
        "${data.azurerm_role_definition.definition2.id}",
        "${data.azurerm_role_definition.definition3.id}"
      ],
      "existenceCondition": {
          "allOf": [
              {
                  "field": "Microsoft.Storage/storageAccounts/allowBlobPublicAccess",
                  "equals": false
              }
          ]
      },
      "deployment": {
        "properties": {
          "mode": "incremental",
          "template": {
            "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
            "contentVersion": "1.0.0.0",
            "parameters": {
                "resourceName": {
                    "type": "String"
                },
                "location": {
                    "type": "String"
                }
            },
            "resources": [
              {
                "name": "[concat(parameters('resourceName'))]",
                "location": "[parameters('location')]",
                "type": "Microsoft.Storage/storageAccounts",
                "apiVersion": "2023-01-01",
                "properties": {
                  "allowBlobPublicAccess": false
                }
              }
            ]
          },
          "parameters": {
              "resourceName": {
                  "value": "[field('name')]"
              },
              "location": {
                  "value": "[field('location')]"
              }
          }
        }
      }
    }
  }
}
POLICY_RULE


  parameters = <<PARAMETERS
{
  "effect": {
    "type": "String",
    "metadata": {
      "displayName": "Effect",
      "description": "The effect determines what happens when the policy rule is evaluated to match"
    },
    "allowedValues": [
      "Audit",
      "Deny",
      "AuditIfNotExists",
      "DeployIfNotExists",
      "Disabled"
    ],
    "defaultValue": "Audit"
  }
}
PARAMETERS
}

# az policy assignment list -g <resource-group-name>
resource "azurerm_resource_group_policy_assignment" "assignment" {
  name                 = "[Custom] Storage account public access should be disallowed"
  resource_group_id    = azurerm_resource_group.this.id
  policy_definition_id = azurerm_policy_definition.policy.id
  location             = azurerm_resource_group.this.location

  non_compliance_message {
      content = "Test Non Compliance Message"
  }

  identity {
      type = "SystemAssigned"
  }

  lifecycle {
    replace_triggered_by = [
      azurerm_policy_definition.policy
    ]
  }

  parameters = <<PARAMETERS
{
  "effect": {
    "value": "DeployIfNotExists"
  }
}
PARAMETERS
}

resource "azurerm_resource_group_policy_remediation" "remeniation" {
  name                 = "remeniation"
  resource_group_id    = azurerm_resource_group.this.id
  policy_assignment_id = azurerm_resource_group_policy_assignment.assignment.id
  location_filters     = [azurerm_resource_group.this.location]
  lifecycle {
    replace_triggered_by = [
      azurerm_policy_definition.policy
    ]
  }
}

data "azurerm_role_definition" "definition1" {
  name = "Contributor"
}

data "azurerm_role_definition" "definition2" {
  name = "Storage Account Contributor"
}

data "azurerm_role_definition" "definition3" {
  name = "Storage Blob Data Contributor"
}

data "azurerm_subscription" "primary" {}

resource "azurerm_role_assignment" "role1" {
  scope              = azurerm_resource_group.this.id
  role_definition_id = data.azurerm_role_definition.definition1.id
  principal_id       = azurerm_resource_group_policy_assignment.assignment.identity[0].principal_id
}

resource "azurerm_role_assignment" "role2" {
  scope              = azurerm_resource_group.this.id
  role_definition_id = data.azurerm_role_definition.definition2.id
  principal_id       = azurerm_resource_group_policy_assignment.assignment.identity[0].principal_id
}

resource "azurerm_role_assignment" "role3" {
  scope              = azurerm_resource_group.this.id
  role_definition_id = data.azurerm_role_definition.definition3.id
  principal_id       = azurerm_resource_group_policy_assignment.assignment.identity[0].principal_id
}
