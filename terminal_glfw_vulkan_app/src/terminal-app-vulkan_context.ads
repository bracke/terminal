with GLFW_Vulkan.Windows;
with System;
with Vk;

package Terminal.App.Vulkan_Context is
   Max_Status_Label_Length : constant := 96;

   type Context is limited private;

   type Init_Status is
     (Ok,
      GLFW_Extensions_Unavailable,
      Instance_Create_Failed,
      Surface_Create_Failed);

   procedure Initialize
     (Ctx    : out Context;
      Window : GLFW_Vulkan.Windows.Window;
      Status : out Init_Status);

   procedure Finalize (Ctx : in out Context);

   function Is_Initialized (Ctx : Context) return Boolean;
   function Instance (Ctx : Context) return Vk.Instance_T;
   function Surface (Ctx : Context) return Vk.Surface_KHR_T;
   function Status_Label (Status : Init_Status) return String;

private
   type Context is limited record
      Initialized : Boolean := False;
      Instance    : Vk.Instance_T := System.Null_Address;
      Surface     : Vk.Surface_KHR_T := System.Null_Address;
   end record;
end Terminal.App.Vulkan_Context;
