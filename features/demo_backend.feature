Feature: Demo Backend API Deployment and Accessibility

  As a DevOps Engineer,
  I want to deploy a secure, internal-only demo API
  So that I have a live target for running post-deployment tests.

  @smoke @integration
  Scenario: Accessing the internal demo API via the public load balancer
    Given the baseline infrastructure is deployed successfully
    When a GET request is sent to the demo API hostname via the public load balancer
    Then the response status code should be 200
    And the response body should contain "Hello from Cloud Run"

  @security
  Scenario: Attempting to access the internal demo API directly
    Given the Cloud Run service is deployed for the demo API
    When a user attempts to connect to the Cloud Run service's direct URL
    Then the connection should be refused or time out
