import { ethers, deployments } from 'hardhat';

export async function getCurrentTime() {
  return (await ethers.provider.getBlock(await ethers.provider.getBlockNumber())).timestamp;
}

export async function TimeGo(s: number) {
  await ethers.provider.send('evm_mine', [(await getCurrentTime()) + s]);
}

export async function getContract(contractName: string) {
  await deployments.fixture([contractName]);
  return await ethers.getContractAt(contractName, (await deployments.get(contractName)).address);
}
