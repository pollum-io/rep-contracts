# Vestar 🏛️

## Overview

Vestar is an innovative real estate crowdfunding platform that integrates blockchain technology with traditional financial infrastructure. It offers tokenized real estate assets, enabling investors to participate in financing new projects and gain a stake in future returns. This approach makes investing in high-potential real estate projects more accessible, liquid, and transparent, benefiting both investors and developers.

## Contracts

**CompliantToken**

An ERC20 token contract with enhanced features for transaction authorization and compliance. It handles token minting, distribution, and maintains a whitelist for regulated transactions.

**CrowdSale**

Manages the token sale process, tracking DREX-funded investments, sale schedules, and enabling refunds under specific conditions. It ensures adherence to sale and claim thresholds, facilitating a seamless crowdfunding experience.

## Quick Start

Follow these steps to set up Vestar:

## Quick Start

First, clone the repository and install the dependencies:

```shell
git clone https://github.com/pollum-io/vestar-contracts
cd vestar-contracts
yarn install
```

To compile the contracts:

```shell
npx hardhat compile
```

This will generate the compiled files in the artifacts folder.
