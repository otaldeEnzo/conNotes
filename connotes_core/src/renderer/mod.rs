pub mod ink_pipeline;
pub mod grid_pipeline;

pub struct Renderer {
    pub device: wgpu::Device,
    pub queue: wgpu::Queue,
    pub ink: ink_pipeline::InkPipeline,
    pub grid: grid_pipeline::GridPipeline,
}

impl Renderer {
    pub async fn new(adapter: &wgpu::Adapter) -> Self {
        let (device, queue) = adapter
            .request_device(&wgpu::DeviceDescriptor::default(), None)
            .await
            .unwrap();

        let ink = ink_pipeline::InkPipeline::new(&device);
        let grid = grid_pipeline::GridPipeline::new(&device);

        Self {
            device,
            queue,
            ink,
            grid,
        }
    }
}
