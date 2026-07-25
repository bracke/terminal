with Interfaces.C;
with GLFW_Vulkan.Raw;
with GLFW_Vulkan.Surfaces;

package body GLFW_Vulkan is
   use type Interfaces.C.int;

   procedure Initialize
     (Ctx    : out Context;
      Status : out Init_Status)
   is
   begin
      if Ctx.Initialized then
         Status := Already_Initialized;
         return;
      end if;

      if Raw.Init = 0 then
         Status := GLFW_Init_Failed;
         return;
      end if;

      if not Surfaces.Vulkan_Supported then
         Raw.Terminate_GLFW;
         Status := Vulkan_Not_Supported;
         return;
      end if;

      Ctx.Initialized := True;
      Status := Ok;
   end Initialize;

   procedure Finalize (Ctx : in out Context) is
   begin
      if Ctx.Initialized then
         Raw.Terminate_GLFW;
         Ctx.Initialized := False;
      end if;
   end Finalize;

   function Is_Initialized (Ctx : Context) return Boolean is
     (Ctx.Initialized);
end GLFW_Vulkan;
