with Vk;
with Vulkan;
with GLFW_Vulkan.Windows;

package GLFW_Vulkan.Surfaces is
   subtype Vulkan_Instance_Handle is Vulkan.Instance_Type;
   subtype Vulkan_Surface_Handle is Vk.Surface_KHR_T;

   Max_Extension_Name_Length : constant := 255;

   type Extension_Name is record
      Length : Natural range 0 .. Max_Extension_Name_Length := 0;
      Text   : String (1 .. Max_Extension_Name_Length) := (others => ASCII.NUL);
   end record;

   type Extension_Name_Array is array (Positive range <>) of Extension_Name;

   function Vulkan_Supported return Boolean;

   function Required_Instance_Extensions return Extension_Name_Array;
   function To_String (Name : Extension_Name) return String;

   type Surface_Status is
     (Ok,
      Window_Invalid,
      Vulkan_Not_Supported,
      Create_Surface_Failed);

   procedure Create_Surface
     (Window   : GLFW_Vulkan.Windows.Window;
      Instance : Vulkan_Instance_Handle;
      Surface  : out Vulkan_Surface_Handle;
      Status   : out Surface_Status);

   procedure Destroy_Surface
     (Instance : Vulkan_Instance_Handle;
      Surface  : in out Vulkan_Surface_Handle);
end GLFW_Vulkan.Surfaces;
