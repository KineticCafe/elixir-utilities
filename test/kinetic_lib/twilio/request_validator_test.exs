defmodule KineticLib.Twilio.RequestValidatorTest do
  use ExUnit.Case, async: true

  alias KineticLib.Twilio.RequestValidator

  defmodule Resolver do
    def token_wrapper, do: "12345"
    def client, do: %{auth_token: token_wrapper()}
    def client_token_wrapper, do: %{auth_token: &token_wrapper/0}

    def token_locator(_), do: token_wrapper()
    def token_wrapper_locator(_), do: &token_wrapper/0
    def client_locator(_), do: client()
    def client_token_wrapper_locator(_), do: client_token_wrapper()
  end

  describe "valid?/4" do
    setup do
      {:ok,
       %{
         token: "12345",
         url: "https://mycompany.com/myapp.php?foo=1&bar=2",
         default_signature: "RSOYDt4T1cUTdK1PDd93/VVr8B8=",
         body: ~S[{"property": "value", "boolean": true}],
         body_hash: "0a1ff7634d9ab3b95db5c9a2dfe9416e41502b283a80c7cf19632632f96e6620",
         params: %{
           "From" => "+14158675309",
           "To" => "+18005551212",
           "CallSid" => "CA1234567890ABCDE",
           "Caller" => "+14158675309",
           "Digits" => "1234"
         }
       }}
    end

    test "builds the correct signature for validation", context do
      assert context.default_signature ==
               RequestValidator.__build_signature(context.token, context.url, context.params)
    end

    test "builds the correct signature for validation with http", context do
      url = String.replace(context.url, "https", "http")

      assert "OyGYPqTF6ztdbRNCvuQO/oPvqQ4=" ==
               RequestValidator.__build_signature(context.token, url, context.params)
    end

    test "passes with an authentic Twilio request", context do
      assert RequestValidator.valid?(
               context.default_signature,
               context.token,
               context.url,
               context.params
             )
    end

    test "fails with an invalid signature", context do
      refute RequestValidator.valid?("fake_signature", context.token, context.url, context.params)
    end

    test "passes requests with a body correctly", context do
      url_with_hash = context.url <> "&bodySHA256=#{context.body_hash}"
      signature = "a9nBmqA0ju/hNViExpshrM61xv4="
      assert RequestValidator.valid?(signature, context.token, url_with_hash, context.body)
    end

    test "passes with no other GET parameters", context do
      url_with_hash = "https://mycompany.com/myapp.php?bodySHA256=#{context.body_hash}"
      signature = "y77kIzt2vzLz71DgmJGsen2scGs="
      assert RequestValidator.valid?(signature, context.token, url_with_hash, context.body)
    end

    test "fails with body but no signature", context do
      refute RequestValidator.valid?(
               context.default_signature,
               context.token,
               context.url,
               context.body
             )
    end

    test "fails with body but no query parameters", context do
      [url_without_params | _] = String.split(context.url, "?")

      refute RequestValidator.valid?(
               context.default_signature,
               context.token,
               url_without_params,
               context.body
             )
    end

    test "passes https urls with ports by stripping them", context do
      url_with_port = String.replace(context.url, ".com", ".com:1234")

      assert RequestValidator.valid?(
               context.default_signature,
               context.token,
               url_with_port,
               context.params
             )
    end

    test "passes https urls without ports by adding standard port 443", context do
      # hash of https url with port 443
      signature = "kvajT1Ptam85bY51eRf/AJRuM3w="
      assert RequestValidator.valid?(signature, context.token, context.url, context.params)
    end

    test "passes urls without ports by adding standard port 80", context do
      http_url = String.replace(context.url, "https", "http")
      # hash of http url with port 80
      signature = "0ZXoZLH/DfblKGATFgpif+LLRf4="
      assert RequestValidator.valid?(signature, context.token, http_url, context.params)
    end

    test "passes urls with credentials", context do
      url_with_creds = "https://user:pass@mycompany.com/myapp.php?foo=1&bar=2"
      # expected hash of the url
      signature = "CukzLTc1tT5dXEDIHm/tKBanW10="
      assert RequestValidator.valid?(signature, context.token, url_with_creds, context.params)
    end

    test "passes urls with just username", context do
      url_with_creds = "https://user@mycompany.com/myapp.php?foo=1&bar=2"
      # expected hash of the url
      signature = "2YRLlVAflCqxaNicjMpJcSTgzSs="
      assert RequestValidator.valid?(signature, context.token, url_with_creds, context.params)
    end

    test "passes urls with credentials by adding port", context do
      url_with_creds = "https://user:pass@mycompany.com/myapp.php?foo=1&bar=2"
      # expected hash of the url with port 443
      signature = "ZQFR1PTIZXF2MXB8ZnKCvnnA+rI="
      assert RequestValidator.valid?(signature, context.token, url_with_creds, context.params)
    end
  end

  describe "ex_twilio: validating a voice request" do
    setup do
      params = %{
        "ToState" => "California",
        "CalledState" => "California",
        "Direction" => "inbound",
        "FromState" => "CA",
        "AccountSid" => "AC_this_is_a_fake_account_sid",
        "Caller" => "+14155551212",
        "CallerZip" => "90210",
        "CallerCountry" => "US",
        "From" => "+14155551212",
        "FromCity" => "SAN FRANCISCO",
        "CallerCity" => "SAN FRANCISCO",
        "To" => "+14155551212",
        "FromZip" => "90210",
        "FromCountry" => "US",
        "ToCity" => "",
        "CallStatus" => "ringing",
        "CalledCity" => "",
        "CallerState" => "CA",
        "CalledZip" => "",
        "ToZip" => "",
        "ToCountry" => "US",
        "CallSid" => "CA_this_is_a_fake_call_sid",
        "CalledCountry" => "US",
        "Called" => "+14155551212",
        "ApiVersion" => "2010-04-01",
        "ApplicationSid" => "AP_this_is_a_fake_application_sid"
      }

      {:ok,
       %{
         params: params,
         signature: "eVZtLKputGHmDL6KrZjkHnhN7ao=",
         token: "this_is_a_fake_token",
         url: "http://twiliotests.example.com/validate/sms"
       }}
    end

    test "passes a correct voice request", context do
      assert RequestValidator.valid?(
               context.signature,
               context.token,
               context.url,
               context.params
             )
    end

    test "fails an incorrect voice request", context do
      refute RequestValidator.valid?("incorrect", context.token, context.url, context.params)
    end
  end

  describe "ex_twilio: validating a text request" do
    setup do
      params = %{
        "ToState" => "CA",
        "FromState" => "CA",
        "AccountSid" => "AC_this_is_a_fake_account_sid",
        "SmsMessageSid" => "SM_this_is_a_fake_sms_message_sid",
        "Body" => "Orly",
        "From" => "+14155551212",
        "FromCity" => "SAN FRANCISCO",
        "SmsStatus" => "received",
        "FromZip" => "90210",
        "FromCountry" => "US",
        "To" => "+14155551212",
        "ToCity" => "SAN FRANCISCO",
        "ToZip" => "90210",
        "ToCountry" => "US",
        "ApiVersion" => "2010-04-01",
        "SmsSid" => "SM_this_is_a_fake_sms_message_sid"
      }

      {:ok,
       [
         params: params,
         signature: "WC3PFsxZQ8xdzhgPhew/S7MDaUw=",
         token: "this_is_a_fake_token",
         url: "http://twiliotests.example.com/validate/sms"
       ]}
    end

    test "passes a correct sms request", context do
      assert RequestValidator.valid?(
               context.signature,
               context.token,
               context.url,
               context.params
             )
    end

    test "fails an incorrect sms request", context do
      refute RequestValidator.valid?("incorrect", context.token, context.url, context.params)
    end
  end

  describe "auth_token resolution" do
    test "binary" do
      assert {:ok, "12345"} =
               RequestValidator.__resolve_auth_token(Resolver.token_wrapper(), %{}, %{})
    end

    test "secret wrapper" do
      assert {:ok, "12345"} =
               RequestValidator.__resolve_auth_token(&Resolver.token_wrapper/0, %{}, %{})
    end

    test "binary in a map" do
      assert {:ok, "12345"} = RequestValidator.__resolve_auth_token(Resolver.client(), %{}, %{})
    end

    test "secret wrapper in a map" do
      assert {:ok, "12345"} =
               RequestValidator.__resolve_auth_token(Resolver.client_token_wrapper(), %{}, %{})
    end

    test "binary from a locator" do
      assert {:ok, "12345"} =
               RequestValidator.__resolve_auth_token(
                 &Resolver.token_locator/1,
                 %{"AccountSID" => "1"},
                 %{}
               )
    end

    test "binary from a locator (mfa)" do
      assert {:ok, "12345"} =
               RequestValidator.__resolve_auth_token(
                 {Resolver, :token_locator, []},
                 %{"AccountSID" => "1"},
                 %{}
               )
    end

    test "secret wrapper from a locator (the account SID is in the query parameters)" do
      assert {:ok, "12345"} =
               RequestValidator.__resolve_auth_token(
                 &Resolver.token_wrapper_locator/1,
                 %{},
                 %{"AccountSID" => "1"}
               )
    end

    test "secret wrapper from a locator (mfa)" do
      assert {:ok, "12345"} =
               RequestValidator.__resolve_auth_token(
                 {Resolver, :token_wrapper_locator, []},
                 %{"AccountSID" => "1"},
                 %{}
               )
    end

    test "binary in a map from a locator" do
      assert {:ok, "12345"} =
               RequestValidator.__resolve_auth_token(
                 &Resolver.client_locator/1,
                 %{"AccountSID" => "1"},
                 %{}
               )
    end

    test "binary in a map from a locator (mfa)" do
      assert {:ok, "12345"} =
               RequestValidator.__resolve_auth_token(
                 {Resolver, :client_locator, []},
                 %{"AccountSID" => "1"},
                 %{}
               )
    end

    test "secret wrapper in a map from a locator" do
      assert {:ok, "12345"} =
               RequestValidator.__resolve_auth_token(
                 &Resolver.client_token_wrapper_locator/1,
                 %{"AccountSID" => "1"},
                 %{}
               )
    end

    test "secret wrapper in a map from a locator (mfa)" do
      assert {:ok, "12345"} =
               RequestValidator.__resolve_auth_token(
                 {Resolver, :client_token_wrapper_locator, []},
                 %{"AccountSID" => "1"},
                 %{}
               )
    end

    test "locators fail without an AccountSID" do
      assert :error = RequestValidator.__resolve_auth_token(&Resolver.token_locator/1, %{}, %{})
    end
  end
end
