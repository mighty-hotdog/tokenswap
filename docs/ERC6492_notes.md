# ERC6492 - Signature Verification For Smart Contract Accounts That Have Not Been Deployed Yet

author:     mighty_hotdog  
created:    07Aug2026  

ERC6492 extends ERC1271 by specifying 2 sets of behaviors, one for the signer, and the other for the verifier.

The signer specification is to produce specially wrapped signatures that signal to the verifier about the status of the signer contract and its readiness to receive ERC1271 calls of `isValidSignature()`. These wrapped signatures also include information that the verifier may use to "hasten" the deployment of the signer contract, and/or otherwise help accelerate its readiness to receive `isValidSignature()` calls.

The verifier specification is to inspect the wrapped signatures and take specific actions based on their content. These actions include trying to deploy the signer contract directly, making the regular ERC1271 `isValidSignature()` call, or falling back to `ecrecover()`.

It's worthwhile to note here that the signer is often a contract wallet that gets a token owner to sign messages to authorize actions to be taken on his behalf. The verifier is often an app that the user/owner interacts with (eg: defi exchange), that receives the signature and needs to verify it before executing the user request.