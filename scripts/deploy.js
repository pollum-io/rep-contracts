const hre = require("hardhat");

async function main() {

  // Token Params
  const initialSupply = "1000000000000000000000000"; // equivalent to 1000e18
  const name = "CrowdSale Test"
  const symbol = "CST1"

  // Sale params
  const drex = "0xc4baf91be09e5d5cbbdd78844c2877f9c85e4474"
  const duration = 86400 * 7 // 7 days
  const openTime = (Date.now() / 1000 + 600).toFixed() // in 10 min
  const releaseTime = openTime + duration + 1
  const releaseDuration = 1
  const saleAmountDrex = "10000000000000" // 10MM
  const saleAmountToken = "200000000000000000000000"
  const minimumSaleAmountForClaim = "140000000000000000000000"
  const fundingWallet = "0xc84633Af14e43F00D5aaa7A47B8d0864eE6a46FB"

  // deploy token
  const CompliantToken = await hre.ethers.getContractFactory("CompliantToken");
  const compliantToken = await CompliantToken.deploy(initialSupply, name, symbol);
  await compliantToken.deployed();
 
  //  deploy sale
  const CrowdSale = await hre.ethers.getContractFactory("CrowdSale");
  const crowdSale = await CrowdSale.deploy(compliantToken.address, drex,duration,openTime, releaseTime, releaseDuration, saleAmountDrex,saleAmountToken, minimumSaleAmountForClaim,fundingWallet);
  await crowdSale.deployed();

  
  //  load sale
  await compliantToken.approve(crowdSale.address, saleAmountToken)
  await compliantToken.mint("0xbcF268A422461cf271e928C70AB1edafD672CAf1", saleAmountToken)
  console.log(await compliantToken.balanceOf("0xbcF268A422461cf271e928C70AB1edafD672CAf1"))
  console.log(await compliantToken.allowance("0xbcF268A422461cf271e928C70AB1edafD672CAf1", crowdSale.address))
  console.log(await compliantToken.owner())
  // await crowdSale.loadSale()

  // verify contracts
  // await hre.run("verify:verify", {
  //   address: compliantToken.address,
  //   constructorArguments: [initialSupply, name, symbol],
  // });
  // await hre.run("verify:verify", {
  //   address: crowdSale.address,
  //   constructorArguments: [compliantToken.address, drex,duration,openTime, releaseTime, releaseDuration, saleAmountDrex,saleAmountToken, minimumSaleAmountForClaim,fundingWallet],
  // });

  // // log addresses
  console.log("CompliantToken address:", compliantToken.address)
  console.log("CrowdSale address:", crowdSale.address)

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
