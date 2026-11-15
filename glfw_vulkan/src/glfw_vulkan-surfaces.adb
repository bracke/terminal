with Ada.Finalization;
with Interfaces.C;
with Interfaces.C.Strings;
with GLFW_Vulkan.Raw;
with GLFW_Vulkan.Windows;
with GLFW_Vulkan.Windows.Internal;
with System;
with System.Address_To_Access_Conversions;
with System.Storage_Elements;
with Vk;

package body GLFW_Vulkan.Surfaces is
   use type Interfaces.C.int;
   use type Interfaces.C.unsigned;
   use type Interfaces.C.Strings.chars_ptr;
   use type GLFW_Vulkan.Raw.GLFW_Window_Handle;
   use type System.Address;
   use System.Storage_Elements;
   use type Vk.Instance_T;
   use type Vk.Surface_KHR_T;

   package Extension_Pointer_Conversions is
     new System.Address_To_Access_Conversions
       (Interfaces.C.Strings.chars_ptr);

   Extension_Pointer_Bytes : constant Storage_Offset :=
     Interfaces.C.Strings.chars_ptr'Size / System.Storage_Unit;

   type Surface_Acquisition is
     new Ada.Finalization.Limited_Controlled with record
      Instance : Vulkan_Instance_Handle := System.Null_Address;
      Surface  : aliased Vulkan_Surface_Handle := System.Null_Address;
   end record;
   overriding procedure Finalize (Item : in out Surface_Acquisition);

   protected Surface_Publication is
      procedure Publish
        (Target : in out Vulkan_Surface_Handle;
         Source : in out Surface_Acquisition);
   end Surface_Publication;

   protected body Surface_Publication is
      procedure Publish
        (Target : in out Vulkan_Surface_Handle;
         Source : in out Surface_Acquisition) is
      begin
         Target := Source.Surface;
         Source.Surface := System.Null_Address;
      end Publish;
   end Surface_Publication;

   overriding procedure Finalize (Item : in out Surface_Acquisition) is
      Owned : constant Vulkan_Surface_Handle := Item.Surface;
   begin
      Item.Surface := System.Null_Address;
      if Owned /= System.Null_Address
        and then Item.Instance /= System.Null_Address
      then
         Vk.Destroy_Surface_KHR
           (Item.Instance, Owned, System.Null_Address);
      end if;
   end Finalize;

   function Vulkan_Supported return Boolean is
     (Raw.Vulkan_Supported /= 0);

   function Required_Instance_Extensions return Extension_Name_Array is
      Count : aliased Interfaces.C.unsigned := 0;
      Ptrs  : constant System.Address :=
        Raw.Get_Required_Instance_Extensions (Count'Access);
   begin
      if Ptrs = System.Null_Address or else Count = 0 then
         return (1 .. 0 => (others => <>));
      end if;

      declare
         Last : constant Positive := Positive (Count);
         Result : Extension_Name_Array (1 .. Last);
      begin
         for I in Result'Range loop
            declare
               P : constant Interfaces.C.Strings.chars_ptr :=
                 Extension_Pointer_Conversions.To_Pointer
                   (Ptrs
                    + Storage_Offset (I - 1) * Extension_Pointer_Bytes).all;
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
      Acquired : Surface_Acquisition;
      Result   : Interfaces.C.int;
   begin
      Surface := System.Null_Address;
      if GLFW_Vulkan.Windows.Internal.Handle (Window) = Raw.Null_Window then
         Status := Window_Invalid;
         return;
      elsif not Vulkan_Supported then
         Status := Vulkan_Not_Supported;
         return;
      end if;

      Acquired.Instance := Instance;
      Result := Raw.Create_Window_Surface
        (Instance,
         GLFW_Vulkan.Windows.Internal.Handle (Window),
         System.Null_Address,
         Acquired.Surface'Address);
      if Result = 0 and then Acquired.Surface /= System.Null_Address then
         Surface_Publication.Publish (Surface, Acquired);
         Status := Ok;
      else
         Status := Create_Surface_Failed;
      end if;
   end Create_Surface;

   procedure Destroy_Surface
     (Instance : Vulkan_Instance_Handle;
      Surface  : in out Vulkan_Surface_Handle)
   is
      Owned_Surface : constant Vulkan_Surface_Handle := Surface;
   begin
      --  Clear the ownership marker before entering foreign code.  A failing
      --  driver call must never make a later cleanup attempt destroy the same
      --  Vulkan object twice.
      Surface := System.Null_Address;
      if Owned_Surface /= System.Null_Address
        and then Instance /= System.Null_Address
      then
         Vk.Destroy_Surface_KHR
           (Instance, Owned_Surface, System.Null_Address);
      end if;
   end Destroy_Surface;
end GLFW_Vulkan.Surfaces;
