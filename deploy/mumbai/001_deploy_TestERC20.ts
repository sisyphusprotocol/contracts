import { DeployFunction } from 'hardhat-deploy/types';

const func: DeployFunction = async function ({ deployments, getNamedAccounts }) {
  // comment it as it's not necessary to deploy a new erc20
  // const { deploy } = deployments;
  // const { deployer } = await getNamedAccounts();
  // await deploy('TestERC20', {
  //   from: deployer,
  //   args: ['TestSisyphus', 'TSS', 0],
  //   log: true,
  // });
};

func.tags = [];
export default func;
