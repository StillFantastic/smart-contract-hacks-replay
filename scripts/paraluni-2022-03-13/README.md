## Paraluni

* Date: 2022-03-13
* Chain: BSC
* Exploit tx: [tx](https://bscscan.com/tx/0x70f367b9420ac2654a5223cc311c7f9c361736a39fd4e7dff9ed1b85bab7ad54)

The deposit functions allows reentrancy, also the contract doens't check if supplied tokens are the ones in the pool, so an attacker could supply
a crafted token and re-enter during token transfer, doubling claimable LP token amount in the protocol.

### Reference
* [peckshield](https://twitter.com/peckshield/status/1502817251564564493/photo/1)
