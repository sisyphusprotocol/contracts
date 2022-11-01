import { DeployFunction } from 'hardhat-deploy/types';

const func: DeployFunction = async function ({ deployments, getNamedAccounts }) {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy('Campaign', {
    from: deployer,
    args: [],
    log: true,
  });
};

func.tags = [];
export default func;
