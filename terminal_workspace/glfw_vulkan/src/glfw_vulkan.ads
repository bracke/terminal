package GLFW_Vulkan is
   type Context is limited private;

   type Init_Status is
     (Ok,
      Already_Initialized,
      GLFW_Init_Failed,
      Vulkan_Not_Supported);

   procedure Initialize
     (Ctx    : out Context;
      Status : out Init_Status);

   procedure Finalize (Ctx : in out Context);

   function Is_Initialized (Ctx : Context) return Boolean;

private
   type Context is limited record
      Initialized : Boolean := False;
   end record;
end GLFW_Vulkan;

