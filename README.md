## Oparcade Smart Contract

### Developer instructions

#### Install dependencies
`yarn install`

#### Create .env file and make sure it's having following information:
```
INFURA_KEY = INFURA_KEY
PK = YOUR_PRIVATE_KEY
API_KEY = YOUR_ETHERSCAN_API_KEY
```

#### Compile code
- `npx hardhat clean` (Clears the cache and deletes all artifacts)
- `npx hardhat compile` (Compiles the entire project, building all artifacts)

#### Run tests
- `npx hardhat test test/{desired_test_script}`

#### Deploy code 
- `npx hardhat node` (Starts a JSON-RPC server on top of Hardhat Network)
- `npx hardhat run --network {network} scripts/{desired_deployment_script}`

#### Etherscan verification
- `npx hardhat verify --network {network} {deployed_contract_address} {constructor_parameters}`
