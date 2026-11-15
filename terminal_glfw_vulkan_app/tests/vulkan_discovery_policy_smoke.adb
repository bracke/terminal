with Ada.Unchecked_Deallocation;
with AUnit.Assertions;
with Interfaces;
with System;
with Vk;

with Terminal.App.Vulkan_Enumeration;
with Terminal.App.Vulkan_Creation_Plan;
with Terminal.App.Vulkan_Queue_Selection;

procedure Vulkan_Discovery_Policy_Smoke is
   use AUnit.Assertions;
   use type Interfaces.Unsigned_32;
   use type Interfaces.Unsigned_64;
   use type System.Address;

   type Item_Array is array (Positive range <>) of Interfaces.Unsigned_32;
   type Item_Array_Access is access Item_Array;
   procedure Free is new Ada.Unchecked_Deallocation
     (Item_Array, Item_Array_Access);

   type Query_Mode is
     (Grow_Once, Always_Incomplete, Empty_Result, Disappearing_Result,
      Oversized_Result,
      Limited_Result,
      Failed_Result);
   Mode  : Query_Mode := Grow_Once;
   Calls : Natural := 0;

   function Mock_Query
     (Count : not null access Interfaces.Unsigned_32;
      Data  : System.Address) return Vk.Result_T
   is
   begin
      Calls := Calls + 1;
      case Mode is
         when Grow_Once =>
            if Data = System.Null_Address then
               Count.all := (if Calls <= 2 then 1 else 2);
               return Vk.SUCCESS;
            elsif Calls = 2 then
               Count.all := 1;
               return Vk.INCOMPLETE;
            else
               Count.all := 2;
               return Vk.SUCCESS;
            end if;
         when Always_Incomplete =>
            Count.all := 1;
            return (if Data = System.Null_Address then Vk.SUCCESS
                    else Vk.INCOMPLETE);
         when Empty_Result =>
            Count.all := 0;
            return Vk.SUCCESS;
         when Disappearing_Result =>
            Count.all := (if Data = System.Null_Address then 1 else 0);
            return Vk.SUCCESS;
         when Oversized_Result =>
            Count.all := Interfaces.Unsigned_32'Last;
            return Vk.SUCCESS;
         when Limited_Result =>
            Count.all := 9;
            return Vk.SUCCESS;
         when Failed_Result =>
            return Vk.ERROR_INITIALIZATION_FAILED;
      end case;
   end Mock_Query;

   package Enumeration is new Terminal.App.Vulkan_Enumeration
     (Element_Type         => Interfaces.Unsigned_32,
      Element_Array        => Item_Array,
      Element_Array_Access => Item_Array_Access,
      Query                => Mock_Query);
   use type Enumeration.Fetch_Status;

   Items  : Item_Array_Access := null;
   Count  : Natural := 0;
   Status : Enumeration.Fetch_Status;
   Queues : Terminal.App.Vulkan_Queue_Selection.Choice;
   Queue_Plan : Terminal.App.Vulkan_Creation_Plan.Queue_Plan;
begin
   Enumeration.Fetch (3, 8, Items, Count, Status);
   Assert
     (Status = Enumeration.Fetch_Ready and then Count = 2 and then Calls = 4,
      "enumeration should retry a changing result set");
   Free (Items);

   Mode := Always_Incomplete;
   Calls := 0;
   Enumeration.Fetch (3, 8, Items, Count, Status);
   Assert
     (Status = Enumeration.Fetch_Retry_Exhausted
      and then Items = null and then Calls = 6,
      "enumeration should bound repeated incomplete results");

   Mode := Empty_Result;
   Calls := 0;
   Enumeration.Fetch (3, 8, Items, Count, Status);
   Assert
     (Status = Enumeration.Fetch_Empty and then Count = 0,
      "enumeration should distinguish an empty result");

   Mode := Disappearing_Result;
   Enumeration.Fetch (3, 8, Items, Count, Status);
   Assert
     (Status = Enumeration.Fetch_Empty and then Items = null,
      "enumeration should handle results disappearing between queries");

   if Interfaces.Unsigned_64 (Interfaces.Unsigned_32'Last) >
     Interfaces.Unsigned_64 (Natural'Last)
   then
      Mode := Oversized_Result;
      Enumeration.Fetch (3, 8, Items, Count, Status);
      Assert
        (Status = Enumeration.Fetch_Count_Too_Large and then Items = null,
         "enumeration should reject counts outside Natural");
   end if;

   Mode := Limited_Result;
   Enumeration.Fetch (3, 8, Items, Count, Status);
   Assert
     (Status = Enumeration.Fetch_Count_Too_Large and then Items = null,
      "enumeration should enforce its practical item limit");

   Mode := Failed_Result;
   Enumeration.Fetch (3, 8, Items, Count, Status);
   Assert
     (Status = Enumeration.Fetch_Query_Failed and then Items = null,
      "enumeration should preserve query failures");

   Terminal.App.Vulkan_Queue_Selection.Consider
     (Queues, 2, Has_Graphics => True, Has_Present => False);
   Terminal.App.Vulkan_Queue_Selection.Consider
     (Queues, 5, Has_Graphics => False, Has_Present => True);
   Assert
     (Terminal.App.Vulkan_Queue_Selection.Complete (Queues)
      and then not Terminal.App.Vulkan_Queue_Selection.Shared (Queues)
      and then Terminal.App.Vulkan_Queue_Selection.Graphics_Index (Queues) = 2
      and then Terminal.App.Vulkan_Queue_Selection.Present_Index (Queues) = 5,
      "selection should accept separate graphics and presentation queues");

   Queue_Plan := Terminal.App.Vulkan_Creation_Plan.Build_Queue_Plan (2, 5);
   Assert
     (Queue_Plan.Graphics_Family = 2
      and then Queue_Plan.Present_Family = 5
      and then Queue_Plan.Device_Queue_Info_Count = 2
      and then Queue_Plan.Swapchain_Queue_Family_Count = 2
      and then Queue_Plan.Concurrent_Sharing,
      "split queues should produce two device queues and concurrent sharing");

   Terminal.App.Vulkan_Queue_Selection.Consider
     (Queues, 7, Has_Graphics => True, Has_Present => True);
   Assert
     (Terminal.App.Vulkan_Queue_Selection.Shared (Queues)
      and then Terminal.App.Vulkan_Queue_Selection.Graphics_Index (Queues) = 7
      and then Terminal.App.Vulkan_Queue_Selection.Present_Index (Queues) = 7,
      "selection should prefer a shared queue when one is found");

   Queue_Plan := Terminal.App.Vulkan_Creation_Plan.Build_Queue_Plan (7, 7);
   Assert
     (Queue_Plan.Device_Queue_Info_Count = 1
      and then Queue_Plan.Swapchain_Queue_Family_Count = 0
      and then not Queue_Plan.Concurrent_Sharing,
      "shared queues should produce one device queue and exclusive sharing");

   Assert
     (Terminal.App.Vulkan_Creation_Plan.Extent_Is_Valid (1, 65_536, 65_536)
      and then not Terminal.App.Vulkan_Creation_Plan.Extent_Is_Valid
        (0, 1, 65_536)
      and then not Terminal.App.Vulkan_Creation_Plan.Extent_Is_Valid
        (65_537, 1, 65_536)
      and then not Terminal.App.Vulkan_Creation_Plan.Extent_Is_Valid
        (Interfaces.Unsigned_32'Last, 1, 65_536),
      "swapchain extents should be nonzero, representable, and bounded");
end Vulkan_Discovery_Policy_Smoke;
