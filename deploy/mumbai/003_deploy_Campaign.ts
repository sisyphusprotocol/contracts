import { DeployFunction } from 'hardhat-deploy/types';

const func: DeployFunction = async function ({ deployments, getNamedAccounts }) {
  const { deploy, get } = deployments;
  const { deployer } = await getNamedAccounts();

  const renderer = await get('Renderer');

  await deploy('Campaign', {
    from: deployer,
    args: [renderer.address],
    log: true,
  });
};

func.tags = ['Campaign'];
func.dependencies = ['Renderer'];
export default func;
