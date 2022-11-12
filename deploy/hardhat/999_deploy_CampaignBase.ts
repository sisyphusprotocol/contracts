import { DeployFunction } from 'hardhat-deploy/types';

/// @note This is only used in hardhat test environments
const func: DeployFunction = async function ({ deployments, getNamedAccounts }) {
  const { deploy, get } = deployments;
  const { deployer } = await getNamedAccounts();

  const renderer = await get('Renderer');

  await deploy('CampaignBase', {
    from: deployer,
    args: [renderer.address],
    log: true,
  });
};

func.tags = ['CampaignBase'];
func.dependencies = ['Renderer'];
export default func;
