Feature: Demo Web App Deployment and Accessibility

  As a DevOps Engineer,
  I want to deploy a secure, internal-only demo Web App
  So that I have a live target for running post-deployment tests.

  @smoke @integration
  Scenario: Accessing the internal demo Web App via the public load balancer
    Given the baseline infrastructure is deployed successfully
    When a GET request is sent to the demo Web App hostname via the public load balancer
    Then the response status code should be 200
    And the response body should contain "Hello from Cloud Run"

  @security
  Scenario: Attempting to access the internal demo Web App directly
    Given the Cloud Run service is deployed for the demo Web App
    When a user attempts to connect to the Cloud Run service's direct URL
    Then the connection should be refused or time out
