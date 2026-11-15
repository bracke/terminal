with Ada.Unchecked_Deallocation;
with Interfaces;
with Interfaces.C;
with System;
with Terminal.App.Vulkan_Enumeration;
with Terminal.App.Vulkan_Queue_Selection;

package body Terminal.App.Vulkan_Device.Selection_Logic is
   package Queue_Selection renames Terminal.App.Vulkan_Queue_Selection;
   use type Interfaces.Unsigned_32;
   use type Interfaces.Unsigned_64;
   use type Interfaces.C.char;
   use type System.Address;
   use type Vk.Queue_Flags_T;
   use type Vk.Result_T;

   type Physical_Device_Array is array
     (Positive range <>) of Vk.Physical_Device_T
     with Convention => C;
   type Queue_Family_Array is array
     (Positive range <>) of Vk.Queue_Family_Properties_T
     with Convention => C;
   type Extension_Array is array
     (Positive range <>) of Vk.Extension_Properties_T
     with Convention => C;
   type Physical_Device_Array_Access is access Physical_Device_Array;
   type Queue_Family_Array_Access is access Queue_Family_Array;
   type Extension_Array_Access is access Extension_Array;
   procedure Free_Physical_Devices is new Ada.Unchecked_Deallocation
     (Physical_Device_Array, Physical_Device_Array_Access);
   procedure Free_Queue_Families is new Ada.Unchecked_Deallocation
     (Queue_Family_Array, Queue_Family_Array_Access);
   procedure Free_Extensions is new Ada.Unchecked_Deallocation
     (Extension_Array, Extension_Array_Access);

   function Fits_Natural (Value : Interfaces.Unsigned_32) return Boolean is
     (Interfaces.Unsigned_64 (Value) <=
        Interfaces.Unsigned_64 (Natural'Last));

   procedure Reset
     (Choice : out Selection;
      Status : Select_Status) is
   begin
      Choice :=
        (Selected                   => False,
         Physical_Device            => System.Null_Address,
         Queue_Family_Index         => 0,
         Present_Queue_Family_Index => 0,
         Physical_Device_Count      => 0,
         Devices_Inspected          => 0,
         Queue_Families_Checked     => 0,
         Surface_Format_Count       => 0,
         Present_Mode_Count         => 0,
         Device_Extensions_Checked  => 0,
         Swapchain_Extension_Found  => False,
         Last_Status                => Status);
   end Reset;

   function Has_Name
     (Item : Vk.Extension_Properties_T;
      Name : String) return Boolean is
   begin
      for I in Name'Range loop
         if Item.extension_Name (I - Name'First) /=
           Interfaces.C.char'Val (Character'Pos (Name (I)))
         then
            return False;
         end if;
      end loop;
      return Item.extension_Name (Name'Length) = Interfaces.C.nul;
   end Has_Name;

   function Swapchain_Support
     (Device  : Vk.Physical_Device_T;
      Checked : out Natural) return Capability_Query_Result
   is
      Extensions : Extension_Array_Access := null;
      Count      : Natural := 0;

      function Query_Extensions
        (Reported : not null access Interfaces.Unsigned_32;
         Data     : System.Address) return Vk.Result_T
      is (Vk.Enumerate_Device_Extension_Properties
            (Device, System.Null_Address, Reported.all'Address, Data));

      package Enumeration is new Terminal.App.Vulkan_Enumeration
        (Element_Type         => Vk.Extension_Properties_T,
         Element_Array        => Extension_Array,
         Element_Array_Access => Extension_Array_Access,
         Query                => Query_Extensions);
      Fetch_Result : Enumeration.Fetch_Status;
   begin
      Checked := 0;
      Enumeration.Fetch
        (Enumeration_Retry_Limit,
         Max_Device_Extensions,
         Extensions,
         Count,
         Fetch_Result);
      case Fetch_Result is
         when Enumeration.Fetch_Ready => null;
         when Enumeration.Fetch_Empty => return Capability_Unavailable;
         when others                  => return Capability_Query_Failed;
      end case;

      Checked := Count;
      for I in 1 .. Count loop
         if Has_Name (Extensions (I), "VK_KHR_swapchain") then
            Free_Extensions (Extensions);
            return Capability_Available;
         end if;
      end loop;
      Free_Extensions (Extensions);
      return Capability_Unavailable;
   exception
      when Storage_Error =>
         Free_Extensions (Extensions);
         return Capability_Query_Failed;
      when others =>
         Free_Extensions (Extensions);
         raise;
   end Swapchain_Support;

   function Surface_Details_Are_Usable
     (Device       : Vk.Physical_Device_T;
      Surface      : Vk.Surface_KHR_T;
      Format_Count : out Natural;
      Mode_Count   : out Natural) return Capability_Query_Result
   is
      Formats : aliased Interfaces.Unsigned_32 := 0;
      Modes   : aliased Interfaces.Unsigned_32 := 0;
      Result  : Vk.Result_T;
   begin
      Format_Count := 0;
      Mode_Count := 0;
      Result := Vk.Get_Physical_Device_Surface_Formats_KHR
        (Device, Surface, Formats'Address, System.Null_Address);
      if Result /= Vk.SUCCESS then
         return Capability_Query_Failed;
      end if;
      Result := Vk.Get_Physical_Device_Surface_Present_Modes_KHR
        (Device, Surface, Modes'Address, System.Null_Address);
      if Result /= Vk.SUCCESS then
         return Capability_Query_Failed;
      elsif not Fits_Natural (Formats)
        or else not Fits_Natural (Modes)
        or else Interfaces.Unsigned_64 (Formats) >
          Interfaces.Unsigned_64 (Max_Surface_Formats)
        or else Interfaces.Unsigned_64 (Modes) >
          Interfaces.Unsigned_64 (Max_Present_Modes)
      then
         return Capability_Query_Failed;
      end if;
      Format_Count := Natural (Formats);
      Mode_Count := Natural (Modes);
      return
        (if Formats > 0 and then Modes > 0
         then Capability_Available
         else Capability_Unavailable);
   end Surface_Details_Are_Usable;

   function Queue_Supports_Present
     (Device      : Vk.Physical_Device_T;
      Surface     : Vk.Surface_KHR_T;
      Queue_Index : Interfaces.Unsigned_32) return Capability_Query_Result
   is
      Supported : aliased Interfaces.Unsigned_32 := 0;
      Result    : constant Vk.Result_T :=
        Vk.Get_Physical_Device_Surface_Support_KHR
          (Device, Queue_Index, Surface, Supported'Address);
   begin
      if Result /= Vk.SUCCESS then
         return Capability_Query_Failed;
      elsif Supported /= 0 then
         return Capability_Available;
      else
         return Capability_Unavailable;
      end if;
   end Queue_Supports_Present;

   procedure Select_Physical_Device
     (Context : Terminal.App.Vulkan_Context.Context;
      Choice  : out Selection;
      Status  : out Select_Status)
   is
      package VC renames Terminal.App.Vulkan_Context;
      Count        : Natural := 0;
      Devices      : Physical_Device_Array_Access := null;
      Surface      : constant Vk.Surface_KHR_T := VC.Surface (Context);
      Query_Failed : Boolean := False;

      function Query_Devices
        (Reported : not null access Interfaces.Unsigned_32;
         Data     : System.Address) return Vk.Result_T
      is (Vk.Enumerate_Physical_Devices
            (VC.Instance (Context), Reported.all'Address, Data));

      package Enumeration is new Terminal.App.Vulkan_Enumeration
        (Element_Type         => Vk.Physical_Device_T,
         Element_Array        => Physical_Device_Array,
         Element_Array_Access => Physical_Device_Array_Access,
         Query                => Query_Devices);
      Fetch_Result : Enumeration.Fetch_Status;
   begin
      Reset (Choice, Context_Not_Initialized);
      if not VC.Is_Initialized (Context) or else Surface = System.Null_Address then
         Status := Context_Not_Initialized;
         Choice.Last_Status := Status;
         return;
      end if;

      Enumeration.Fetch
        (Enumeration_Retry_Limit,
         Max_Physical_Devices,
         Devices,
         Count,
         Fetch_Result);
      case Fetch_Result is
         when Enumeration.Fetch_Ready =>
            Choice.Physical_Device_Count := Count;
         when Enumeration.Fetch_Empty =>
            Status := No_Physical_Devices;
            Choice.Last_Status := Status;
            return;
         when others =>
            Status := Surface_Query_Failed;
            Choice.Last_Status := Status;
            return;
      end case;

      for D in 1 .. Count loop
         declare
            Queue_Count    : aliased Interfaces.Unsigned_32 := 0;
            Queue_Capacity : Natural := 0;
            Queues         : Queue_Family_Array_Access := null;
            Format_Count   : Natural := 0;
            Mode_Count     : Natural := 0;
            Extension_Count : Natural := 0;
            Extension_Result : Capability_Query_Result;
            Surface_Result   : Capability_Query_Result;
            Queue_Choice     : Queue_Selection.Choice;
         begin
            Choice.Devices_Inspected := Choice.Devices_Inspected + 1;
            Extension_Result :=
              Swapchain_Support (Devices (D), Extension_Count);
            if Extension_Result /= Capability_Available then
               Choice.Device_Extensions_Checked :=
                 Choice.Device_Extensions_Checked + Extension_Count;
               Query_Failed := Query_Failed
                 or else Extension_Result = Capability_Query_Failed;
            else
               Surface_Result := Surface_Details_Are_Usable
                 (Devices (D), Surface, Format_Count, Mode_Count);
               if Surface_Result /= Capability_Available then
                  Choice.Device_Extensions_Checked :=
                    Choice.Device_Extensions_Checked + Extension_Count;
                  Choice.Swapchain_Extension_Found := True;
                  Query_Failed := Query_Failed
                    or else Surface_Result = Capability_Query_Failed;
               else
                  Choice.Device_Extensions_Checked :=
                    Choice.Device_Extensions_Checked + Extension_Count;
                  Choice.Swapchain_Extension_Found := True;
                  Vk.Get_Physical_Device_Queue_Family_Properties
                    (Devices (D), Queue_Count'Address, System.Null_Address);
                  if not Fits_Natural (Queue_Count)
                    or else Interfaces.Unsigned_64 (Queue_Count) >
                      Interfaces.Unsigned_64 (Max_Queue_Families)
                  then
                     Query_Failed := True;
                  elsif Queue_Count > 0 then
                     Queue_Capacity := Natural (Queue_Count);
                     Queues :=
                       new Queue_Family_Array (1 .. Queue_Capacity);
                     Vk.Get_Physical_Device_Queue_Family_Properties
                       (Devices (D), Queue_Count'Address, Queues.all'Address);
                     if not Fits_Natural (Queue_Count)
                       or else Interfaces.Unsigned_64 (Queue_Count) >
                         Interfaces.Unsigned_64 (Max_Queue_Families)
                       or else Natural (Queue_Count) > Queue_Capacity
                     then
                        Query_Failed := True;
                        Free_Queue_Families (Queues);
                     else
                        for Q in 1 .. Natural (Queue_Count) loop
                           Choice.Queue_Families_Checked :=
                             Choice.Queue_Families_Checked + 1;
                           declare
                              Queue_Result : constant Capability_Query_Result :=
                                Queue_Supports_Present
                                  (Devices (D), Surface,
                                   Interfaces.Unsigned_32 (Q - 1));
                              Has_Graphics : constant Boolean :=
                                Queues (Q).queue_Count > 0
                                and then
                                  (Queues (Q).queue_Flags and
                                     Vk.QUEUE_GRAPHICS_BIT) /= 0;
                           begin
                              Query_Failed := Query_Failed
                                or else Queue_Result = Capability_Query_Failed;
                              Queue_Selection.Consider
                                (Queue_Choice,
                                 Q - 1,
                                 Has_Graphics,
                                 Queue_Result = Capability_Available);
                              exit when Queue_Selection.Shared (Queue_Choice);
                           end;
                        end loop;
                        if Queue_Selection.Complete (Queue_Choice) then
                           Choice.Selected := True;
                           Choice.Physical_Device := Devices (D);
                           Choice.Queue_Family_Index :=
                             Queue_Selection.Graphics_Index (Queue_Choice);
                           Choice.Present_Queue_Family_Index :=
                             Queue_Selection.Present_Index (Queue_Choice);
                           Choice.Surface_Format_Count := Format_Count;
                           Choice.Present_Mode_Count := Mode_Count;
                           Choice.Last_Status := Ok;
                           Status := Ok;
                           Free_Queue_Families (Queues);
                           Free_Physical_Devices (Devices);
                           return;
                        end if;
                        Free_Queue_Families (Queues);
                     end if;
                  end if;
               end if;
            end if;
         exception
            when Storage_Error =>
               Free_Queue_Families (Queues);
               Query_Failed := True;
            when others =>
               Free_Queue_Families (Queues);
               raise;
         end;
      end loop;

      Status := (if Query_Failed then Surface_Query_Failed
                 else No_Suitable_Device);
      Choice.Last_Status := Status;
      Free_Physical_Devices (Devices);
   exception
      when Storage_Error =>
         Free_Physical_Devices (Devices);
         Status := Surface_Query_Failed;
         Choice.Last_Status := Status;
      when others =>
         Free_Physical_Devices (Devices);
         raise;
   end Select_Physical_Device;

   function Is_Selected (Choice : Selection) return Boolean is
     (Choice.Selected);

   function Physical_Device (Choice : Selection) return Vk.Physical_Device_T is
     (Choice.Physical_Device);

   function Queue_Family_Index (Choice : Selection) return Natural is
     (Choice.Queue_Family_Index);

   function Present_Queue_Family_Index (Choice : Selection) return Natural is
     (Choice.Present_Queue_Family_Index);

   function Diagnostics (Choice : Selection) return Diagnostic_Snapshot is
     ((Selected                    => Choice.Selected,
       Physical_Device_Count       => Choice.Physical_Device_Count,
       Devices_Inspected           => Choice.Devices_Inspected,
       Queue_Families_Checked      => Choice.Queue_Families_Checked,
       Queue_Family_Index          => Choice.Queue_Family_Index,
       Present_Queue_Family_Index  => Choice.Present_Queue_Family_Index,
       Surface_Format_Count        => Choice.Surface_Format_Count,
       Present_Mode_Count          => Choice.Present_Mode_Count,
       Device_Extensions_Checked   => Choice.Device_Extensions_Checked,
       Swapchain_Extension_Found   => Choice.Swapchain_Extension_Found,
       Last_Status                 => Choice.Last_Status));
end Terminal.App.Vulkan_Device.Selection_Logic;
