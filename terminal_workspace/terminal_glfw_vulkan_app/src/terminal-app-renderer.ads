with Terminal.Core;
with Terminal.App.Vulkan_Context;

package Terminal.App.Renderer is
   type Renderer is limited private;

   type Init_Status is (Ok, Vulkan_Adapter_Missing, Failed);
   type Render_Status is (Ok, Failed);

   procedure Initialize
     (R       : out Renderer;
      Context : Terminal.App.Vulkan_Context.Context;
      Status  : out Init_Status);
   procedure Render
     (R        : in out Renderer;
      Snapshot : Terminal.Core.Render_Snapshot;
      Status   : out Render_Status);
   procedure Finalize (R : in out Renderer);

   function Cell_Width (R : Renderer) return Positive;
   function Cell_Height (R : Renderer) return Positive;

private
   type Renderer is limited record
      Initialized : Boolean := False;
      Has_Context : Boolean := False;
      CW          : Positive := 8;
      CH          : Positive := 16;
   end record;
end Terminal.App.Renderer;
