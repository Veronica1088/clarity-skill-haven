import {
    Clarinet,
    Tx,
    Chain,
    Account,
    types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

// [Previous tests remain unchanged...]

Clarinet.test({
    name: "Test course state management",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const instructor = accounts.get('wallet_1')!;
        const student = accounts.get('wallet_2')!;
        
        // Create course
        let createBlock = chain.mineBlock([
            Tx.contractCall('skill_haven', 'create-course', [
                types.ascii("Test Course"),
                types.utf8("Description"),
                types.uint(100)
            ], instructor.address)
        ]);
        
        // Deactivate course
        let toggleBlock = chain.mineBlock([
            Tx.contractCall('skill_haven', 'toggle-course-status', [
                types.uint(1)
            ], instructor.address)
        ]);
        
        // Attempt purchase of inactive course
        let purchaseBlock = chain.mineBlock([
            Tx.contractCall('skill_haven', 'purchase-course', [
                types.uint(1)
            ], student.address)
        ]);
        
        purchaseBlock.receipts[0].result.expectErr().expectUint(107);
    }
});

Clarinet.test({
    name: "Test revenue withdrawal",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const instructor = accounts.get('wallet_1')!;
        const student = accounts.get('wallet_2')!;
        
        // Create and purchase course
        chain.mineBlock([
            Tx.contractCall('skill_haven', 'create-course', [
                types.ascii("Test Course"),
                types.utf8("Description"),
                types.uint(100)
            ], instructor.address),
            Tx.contractCall('skill_haven', 'purchase-course', [
                types.uint(1)
            ], student.address)
        ]);
        
        // Withdraw revenue
        let withdrawBlock = chain.mineBlock([
            Tx.contractCall('skill_haven', 'withdraw-revenue', [], instructor.address)
        ]);
        
        withdrawBlock.receipts[0].result.expectOk().expectUint(95); // 95% of 100
    }
});
