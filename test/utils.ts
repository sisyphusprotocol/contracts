import { Contract } from 'ethers';
import { ethers, deployments, network } from 'hardhat';

export async function getCurrentTime() {
  return (await ethers.provider.getBlock(await ethers.provider.getBlockNumber())).timestamp;
}

export async function TimeGo(s: number) {
  await network.provider.send('evm_mine', [(await getCurrentTime()) + s]);
}

export async function getContract<T extends Contract>(contractName: string) {
  await deployments.fixture([contractName]);
  return await ethers.getContractAt<T>(contractName, (await deployments.get(contractName)).address);
}
