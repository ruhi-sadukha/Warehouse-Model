#!/bin/bash

file=database.txt

# Function to print formatted rows
print_database() {

# Printing header
printf "%-10s %-13s %-10s %-10s\n" "HSN Code" "Product" "Quantity" "MRP"
echo "-------------------------------------------"

# Reading file line by line + skipping the header
tail -n +2 "$file" | while read -r hsn desc qty mrp; do
    printf "%-10s %-13s %-10s %-10s\n" "$hsn" "$desc" "$qty" "$mrp"
done

}

read col_hsn col_desc col_qty col_mrp < <(awk '
NR==1 {
    for (i=1; i<=NF; i++) {
        if ($i == "HSN_Code") col_hsn = i;
        else if ($i == "Product_Description") col_desc = i;
        else if ($i == "Quantity") col_qty = i;
        else if ($i == "MRP") col_mrp = i;
    }
    print col_hsn, col_desc, col_qty, col_mrp; #hsn value column number is col_hsn and so on
}' "$file")

total_units_sold=0
total_transactions=0
total_sales=0
avg_transaction_value=0

generate_report() {
    echo "Date: $(date '+%d-%m-%Y')"
    echo "Location: Thaltej, Ahmedabad"
    echo "Store Name: XYZ Groceries"

    echo -e "\nSales Report\n"

    echo "Total Sales Revenue: $total_sales"
    echo "Number of Transactions: $total_transactions"
    echo "Average Transaction Value: $avg_transaction_value"
    echo "Total Units Sold: $total_units_sold"
}

#xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx Main Code Begins xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

while true; do
clear
read -p "Enter any key to start. " start
echo 
read -p "Enter your name (only if you want it included in the bill): " Name
echo 
    
#-----------------------------------------------------------------------Updating warehouse section 

name=$(echo "$Name" | tr '[:upper:]' '[:lower:]')
admin_pass=$(<admin_pass.txt)  # Reads password from the password file

if [[ "$name" == "admin" ]]; then
    i=0
    while true; do
        read -p "Enter admin password: " pass
    
        if [[ "$pass" == "$admin_pass" ]]; then
            
            while true; do
                clear
                echo -e "Welcome to the warehouse database!\n"
                echo -e "To view or manually update the database, enter the following keys:\n"
                echo "1: View current database."
                echo "2: Add new items or update MRP."
                echo "3: Remove existing items."
                echo "4: Generate sales report."    
                echo "5: Change admin password."
                echo -e "\nEnter any other key to go back."
                read option
                clear
                
                if [[ $option == 1 ]]; then
                    print_database
                    echo -e "\nEnter any key to go back."
                    read 
                
                elif [[ $option == 2 ]]; then
                    while true; do
                        read -p "HSN Code: " add_hsn

                        if [[ ! $add_hsn =~ ^[0-9]+$ ]]; then
                            echo -e "\n⚠︎ Error: HSN Code must have an integer value.\n"
                            continue
                        fi

                        # Checking if the HSN Code already exists
                        existing_hsn=$(awk -v hsn="$add_hsn" -v col_hsn="$col_hsn" '$col_hsn == hsn { print; exit }' "$file")
    
                        if [[ -n $existing_hsn ]]; then
                            existing_desc=$(echo "$existing_hsn" | awk -v col_desc="$col_desc" '{print $col_desc}')
                            existing_qty=$(echo "$existing_hsn" | awk -v col_qty="$col_qty" '{print $col_qty}')
                            existing_mrp=$(echo "$existing_hsn" | awk -v col_mrp="$col_mrp" '{print $col_mrp}')
    
                            echo -e "\nItem: $existing_desc"
                            echo -e "Current Quantity: $existing_qty"
                            echo -e "Current MRP: Rs $existing_mrp\n"
    
                            # Get new quantity and add it to the existing quantity
                            while true; do
                                read -p "Quantity to add (leave blank to keep current): " add_qty
                    
                                if [[ ! $add_qty =~ ^([0-9]+)?$ ]]; then
                                    echo -e "\n⚠︎ Error: Quantity must be a valid integer.\n"
                                    continue
                                fi
                                break
                            done
                    
                            add_qty=${add_qty:-0}
                            new_qty=$(echo "$existing_qty + $add_qty" | bc)
    
                           # Get new MRP, update only if provided
                            while true; do
                                read -p "Update price: MRP Rs (leave blank to keep current): " add_price
                            
                                if [[ ! $add_price =~ ^([0-9]+(\.[0-9])?)?$ ]]; then
                                    echo -e "\n⚠︎ Error: Price value must be a number with upto one decimal point.\n"
                                    continue
                                fi
                                break
                            done
                    
                            new_mrp=${add_price:-$existing_mrp}
    
                            # Update the database file
                            awk -v hsn="$add_hsn" -v col_hsn="$col_hsn" -v col_qty="$col_qty" -v col_mrp="$col_mrp" -v new_qty="$new_qty" -v new_mrp="$new_mrp" '
                            {
                                if ($col_hsn == hsn) {
                                    $col_qty = new_qty;
                                    $col_mrp = new_mrp;
                                }    
                                print $0;
                            }' "$file" > temp && mv temp "$file"

                            echo -e "\nUpdated $existing_desc with new quantity: $new_qty and MRP: Rs $new_mrp.\n"

                        else
                            # New item case
                            read -p "Product description: " add_prod
                            read -p "Quantity (default: 0): " add_qty
                            add_qty=${add_qty:-0}
                            read -p "MRP Rs: " add_price

                         # Append new item to the database
                            echo "$add_hsn $add_prod $add_qty $add_price" >> "$file"
                            echo -e "\nAdded new item: $add_prod with quantity: $add_qty and MRP: Rs $add_price.\n"
                        fi

                        while true; do
                            read -p "Continue with another item? (y/n): " cont
                            if [[ "$cont" == "y" ]]; then
                                echo && break
                            elif [[ "$cont" == "n" ]]; then
                                break 2   
                            else
                                echo -e "\n⚠︎ Invalid choice. Please enter either y for yes or n for no.\n"
                            fi
                        done
                    done
                
                elif [[ $option == 3 ]]; then
                    while true; do
                        read -p "HSN Code: " remove_hsn
                    
                        existing_hsn=$(awk -v hsn="$remove_hsn" -v col_hsn="$col_hsn" '$col_hsn == hsn { print; exit }' "$file")
    
                        if [[ -z "$existing_hsn" ]]; then
                            echo -e "\n⚠︎ Error: HSN code not found\n"
                            continue
                        fi 
                    
                        existing_desc=$(echo "$existing_hsn" | awk -v col_desc="$col_desc" '{print $col_desc}')
                        existing_qty=$(echo "$existing_hsn" | awk -v col_qty="$col_qty" '{print $col_qty}')
                        
                        echo -e "\nItem: $existing_desc"
                        echo -e "Current Quantity: $existing_qty\n"
                        
                        # Get new quantity and remove it from the existing quantity
                        while true; do
                            read -p "Quantity to remove (default: 0): " remove_qty
                            remove_qty=${remove_qty:-0}
                            new_qty=$(echo "$existing_qty - $remove_qty" | bc)
                                
                            if [[ ! $remove_qty =~ ^[0-9]+$ ]]; then
                                echo -e "\n⚠︎ Error: Quantity must be a valid integer.\n"
                                continue
                            elif (( new_qty < 0 )); then
                                echo -e "\n⚠︎ Error: Cannot remove more than available stock.\n"
                                continue
                            fi
                        
                            break
                        done

                        # Update the database file
                        awk -v hsn="$remove_hsn" -v col_hsn="$col_hsn" -v col_qty="$col_qty" -v new_qty="$new_qty" '
                        {
                            if ($col_hsn == hsn) {
                                $col_qty = new_qty;
                            }
                            print $0;
                        }' "$file" > temp && mv temp "$file"

                        echo -e "\nUpdated $existing_desc with new quantity: $new_qty.\n"

                        while true; do
                            read -p "Continue with another item? (y/n): " cont
                            if [[ "$cont" == "y" ]]; then
                                echo && break
                            elif [[ "$cont" == "n" ]]; then
                                break 2   
                            else
                                echo -e "\n⚠︎ Invalid choice. Please enter either y for yes or n for no.\n"
                            fi
                        done
                    done
                
                elif [[ $option == 4 ]]; then
                    generate_report
                    echo -e "\n\nEnter any key to go back."
                    read 
            
                elif [[ $option == 5 ]]; then
                    read -p "Enter new password: " new_pass
                    while true; do
                        echo
                        read -p "Confirm password change? (y/n): " confirm
                        if [[ "$confirm" == "y" ]]; then
                            echo "$new_pass" > admin_pass.txt  # Change password in the password file
                            echo -e "\nPassword updated successfully!\n"
                        elif [[ "$confirm" == "n" ]]; then
                            echo -e "\nPassword change canceled.\n"
                        else
                            echo -e "\n⚠︎ Invalid choice. Please enter either y for yes or n for no."
                            continue
                        fi
                        sleep 2s
                        while read -t 0.1 -n 1000 dummy; do : ; done
                        break
                    done
                
                else
                    continue 3
            
                fi
            done
        else
            ((i++))
            echo -e "\nSorry! The password is incorrect. $((3-i)) chances remaining.\n"
        
            if [[ $i == 3 ]]; then
                sleep 2s
                while read -t 0.1 -n 1000 dummy; do : ; done
                continue 2
            fi
            continue
        fi
        break
    done
fi

#-----------------------------------------------------------------------------------End of section

hour=$(date +%H) 

#(Store hours are 7am to 9pm)
if [[ $hour -lt 12 ]]; then
    echo -e "Good morning $Name! Welcome to our store ☺\n"
elif [[ $hour -ge 12 && $hour -lt 18 ]]; then
    echo -e "Good afternoon $Name! Welcome to our store ☺\n"
else
    echo -e "Good evening $Name! Welcome to our store ☺\n"
fi

print_database

echo -e "\nTo purchase items, enter their HSN codes and quantities."
echo -e "Press enter to finish and generate the bill.\n"

HSN=()
Description=()
Quant_buy=()
New_qty=()
MRP=()
Equivalent=()

index=1

while true; do
    echo "Item $index"
    read -p "HSN Code: " hsn
    
    if [[ -z "$hsn" ]]; then
        while true; do
            echo 
            read -p "Are you sure you want to exit? (y/n): " cont

            if [[ "$cont" == "n" ]]; then
                echo -e "\nContinue adding items:\n"
                continue 2 
            elif [[ "$cont" == "y" ]]; then
                break 2  
            else
                echo -e "\n⚠︎ Invalid choice. Please enter either y for yes or n for no."
                continue
            fi
        done 
    fi
    
    Desc=$(
    awk -v hsn="$hsn" -v col_hsn="$col_hsn" -v description="$col_desc" '{
        if ($col_hsn == hsn) { # Check if HSN code exists anywhere in the column
            print $description; exit
        }
    }' "$file"
    )
    
    if [[ -z "$Desc" ]]; then
        echo -e "\n⚠︎ Error: HSN code not found.\n"
        continue
    fi
    
    qty_store=$(
    awk -v hsn="$hsn" -v col_hsn="$col_hsn" -v quantity="$col_qty" '{
        if ($col_hsn == hsn) { # Check if HSN code exists anywhere in the column
            print $quantity; exit
        }
    }' "$file"
    )
    
    if [[ "$qty_store" == 0 ]]; then
        echo -e "\nSorry, this item is out of stock at the moment.\n"
        continue
    fi
    
    mrp=$(
    awk -v hsn="$hsn" -v col_hsn="$col_hsn" -v price="$col_mrp" '{
        if ($col_hsn == hsn) { # Check if HSN code exists anywhere in the column
            print $price; exit
        }
    }' "$file"
    )
    
    echo "Product: $Desc"    
    
    while true; do
        read -p "Quantity: " qty
        if [[ ! "$qty" =~ ^[0-9]+(\.[0-9])?$ ]]; then
            echo -e "\n⚠︎ Error: Please enter a valid number.\n"
        elif [[ "$qty" -gt "$qty_store" ]]; then
            if [[ $qty_store == 1 ]]; then
                echo -e "\nSorry, only 1 is available right now.\n"
            else
                echo -e "\nSorry, only $qty_store are available right now.\n"
            fi
        elif [[ "$qty" == 0 ]]; then
            echo && continue 2
        else
            echo && break
        fi
    done
    
    equivalent=$(echo "$qty * $mrp" | bc)
    new_qty=$(echo "$qty_store - $qty" | bc)
    
    HSN+=($hsn)
    Description+=($Desc)
    Quant_buy+=($qty)
    New_qty+=($new_qty)
    MRP+=($mrp)
    Equivalent+=($equivalent)
    
    ((index++))
done

#--------------------------------------------------------------------------Bill is being generated

if [ ${#HSN[@]} -eq 0 ]; then
    echo -e "\nNo purchases were made.\n"
else
    echo -e "\nGenerating Bill...\n"

    print_bill() {

    if [[ -n "$Name" ]]; then
        echo -e "Name: $Name\n"
    fi

    printf "%-7s %-10s %-15s %-10s %-10s %-10s\n" "Sr.No." "HSN Code" "Description" "Quantity" "MRP" "Equivalent"

    total=0
    for ((i = 0; i < ${#Description[@]}; i++)); do
        printf "%-7s %-10s %-15s %-10s %-10s %-10s\n" "$((i+1))" "${HSN[i]}" "${Description[i]}" "${Quant_buy[i]}" "${MRP[i]}" "${Equivalent[i]}"
        total=$(echo "$total + ${Equivalent[i]}" | bc)
    done

    echo -e "\nTotal Amount: $total\n"
    }

    print_bill > bill.txt

    cat bill.txt

#-------------------------------------------------------------------------Bill generation finished

    while true; do
        read -p "Confirm purchase? (y/n): " confirm
        if [[ "$confirm" == "y" ]]; then
    
        for ((i = 0; i < ${#Description[@]}; i++)); do
            #Updating product quantity in database
            awk -v hsn="${HSN[i]}" -v new="${New_qty[i]}" -v col_qty="$col_qty" '
            $1 == hsn { 
            $col_qty = new     
            } 
            { print }' "$file" > temp && mv temp "$file"
        done
        
            new_units_sold=$(awk '/^Sr.No./ {found=1; next} found {sum += $4} END {print sum}' bill.txt)
            total_units_sold=$(echo "$total_units_sold + $new_units_sold" | bc)
            total_sales=$(echo "$total_sales + $total" | bc)
            ((total_transactions++))
            
            if [ $total_transactions -gt 0 ]; then
                avg_transaction_value=$(echo "scale=1; $total_sales / $total_transactions" | bc)
            else
                avg_transaction_value=0
            fi

            bill_name=$(date | awk '{print $2, $3, $7, $4}')
            cp bill.txt ~/Documents/Receipts/"$bill_name"
    
            echo -e "\nPurchase complete! Thank you for shopping with us!"

        elif [[ "$confirm" == "n" ]]; then
            echo -e "\nPurchase cancelled."

        else
            echo -e "\nInvalid choice. Please select y for yes or n for no.\n"
            continue
        fi
        break
    done
fi

sleep 3s 
while read -t 0.1 -n 1000 dummy; do : ; done

if [[ $hour -gt 20 ]]; then
    clear
    echo "Our store has closed. Please visit us on the next working day!"
    report_name=$(date | awk '{print $2, $3, $7}')
    generate_report > temp && cp temp ~/Documents/Reports/"$report_name"
    break
fi

done
