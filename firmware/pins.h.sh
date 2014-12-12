#!/bin/bash

echo "# skeleton for pin definitions"
for i in $@
do
cat <<EOF

#define $i 
#define ${i}_DDR  DDR
#define ${i}_PORT PORT
#define ${i}_PIN  PIN

EOF
done

for i in $@
do
cat <<EOF

void ${i}_set(uint8_t value);
void ${i}_as_output(void);
void ${i}_as_input(void);
void ${i}_as_pullup(void);
uint8_t ${i}_state(void);

EOF
done