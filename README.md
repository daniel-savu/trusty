# trusty

This trusty demo exemplifies its usage as a proxy for Aave (and potentially other protocols, see the Compound stub and tests).

Trusty aims to compute a cross-protocol reputation for agents. By performing desired actions in one protocol, the agent can reduce
their collateral ratio across all protocols that integrate with trusty. 

Even if this is the target goal of trusty, at the moment the implementation is simply a demo of Balance (https://github.com/nud3l/balance) applied to Aave.

To compute cross-protocol reputation, trusty will use a web-of-trust component to aggregate trust 'scores' achieved in every protocol.

To run the tests that exemplify the usage of trusty for Aave, you should have Buidler installed (https://buidler.dev/).
You can have a full node running on your machine or use infura and ganache-cli. Check the `buidler.ts.config` modify the network configuration.
In my tests I used the localhost http://127.0.0.1:2000, which has the alias of `playground`.

Finally, run:
`npx buidler --network playground test`
