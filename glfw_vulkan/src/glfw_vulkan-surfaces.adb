with Interfaces.C;
with Interfaces.C.Strings;
with GLFW_Vulkan.Raw;
with GLFW_Vulkan.Windows;
with GLFW_Vulkan.Windows.Internal;
with System;
with Vk;

package body GLFW_Vulkan.Surfaces is
   use type Interfaces.C.int;
   use type Interfaces.C.unsigned;
   use type Interfaces.C.Strings.chars_ptr;
   use type GLFW_Vulkan.Raw.Extension_Pointer_Array_Access;
   use type GLFW_Vulkan.Raw.GLFW_Window_Handle;

   function Vulkan_Supported return Boolean is
     (Raw.Vulkan_Supported /= 0);

   function Required_Instance_Extensions return Extension_Name_Array is
      Count : aliased Interfaces.C.unsigned := 0;
      Ptrs  : constant Raw.Extension_Pointer_Array_Access :=
        Raw.Get_Required_Instance_Extensions (Count'Access);
   begin
      if Ptrs = null or else Count = 0 then
         return (1 .. 0 => (others => <>));
      end if;

      declare
         Last : constant Positive :=
           Positive (Interfaces.C.unsigned'Min (Count, 32));
         Result : Extension_Name_Array (1 .. Last);
      begin
         for I in Result'Range loop
            declare
               P : constant Interfaces.C.Strings.chars_ptr :=
                 Ptrs (Interfaces.C.unsigned (I - 1));
            begin
               if P /= Interfaces.C.Strings.Null_Ptr then
                  declare
                     S : constant String := Interfaces.C.Strings.Value (P);
                     L : constant Natural :=
                       Natural'Min (S'Length, Max_Extension_Name_Length);
                  begin
                     Result (I).Length := L;
                     if L > 0 then
                        Result (I).Text (1 .. L) := S (S'First .. S'First + L - 1);
                     end if;
                  end;
               end if;
            end;
         end loop;
         return Result;
      end;
   end Required_Instance_Extensions;

   function To_String (Name : Extension_Name) return String is
   begin
      if Name.Length = 0 then
         return "";
      else
         return Name.Text (1 .. Name.Length);
      end if;
   end To_String;

   procedure Create_Surface
     (Window   : GLFW_Vulkan.Windows.Window;
      Instance : Vulkan_Instance_Handle;
      Surface  : out Vulkan_Surface_Handle;
      Status   : out Surface_Status)
   is
      Local_Surface : aliased Vk.Surface_KHR_T := System.Null_Address;
      Result        : Interfaces.C.int;
   begin
      if GLFW_Vulkan.Windows.Internal.Handle (Window) = Raw.Null_Window then
         Surface := System.Null_Address;
         Status := Window_Invalid;
         return;
      elsif not Vulkan_Supported then
         Surface := System.Null_Address;
         Status := Vulkan_Not_Supported;
         return;
      end if;

      Result := Raw.Create_Window_Surface
        (Instance,
         GLFW_Vulkan.Windows.Internal.Handle (Window),
         Local_Surface'Address);
      Surface := Local_Surface;
      Status := (if Result = 0 then Ok else Create_Surface_Failed);
   end Create_Surface;

   procedure Destroy_Surface
     (Instance : Vulkan_Instance_Handle;
      Surface  : in out Vulkan_Surface_Handle)
   is
      pragma Unreferenced (Instance);
   begin
      Surface := System.Null_Address;
   end Destroy_Surface;
end GLFW_Vulkan.Surfaces;
