import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Test course creation and retrieval",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const instructor = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('skill_haven', 'create-course', [
                types.ascii("Learn Pottery"),
                types.utf8("A comprehensive course on pottery making"),
                types.uint(100)
            ], instructor.address)
        ]);
        
        block.receipts[0].result.expectOk().expectUint(1);
        
        let courseBlock = chain.mineBlock([
            Tx.contractCall('skill_haven', 'get-course', [
                types.uint(1)
            ], instructor.address)
        ]);
        
        const course = courseBlock.receipts[0].result.expectSome().expectTuple();
        assertEquals(course.title, "Learn Pottery");
        assertEquals(course.price, types.uint(100));
    }
});

Clarinet.test({
    name: "Test course purchase and enrollment",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const instructor = accounts.get('wallet_1')!;
        const student = accounts.get('wallet_2')!;
        
        // Create course
        let createBlock = chain.mineBlock([
            Tx.contractCall('skill_haven', 'create-course', [
                types.ascii("Learn Pottery"),
                types.utf8("A comprehensive course on pottery making"),
                types.uint(100)
            ], instructor.address)
        ]);
        
        // Purchase course
        let purchaseBlock = chain.mineBlock([
            Tx.contractCall('skill_haven', 'purchase-course', [
                types.uint(1)
            ], student.address)
        ]);
        
        purchaseBlock.receipts[0].result.expectOk().expectBool(true);
        
        // Verify enrollment
        let enrollmentBlock = chain.mineBlock([
            Tx.contractCall('skill_haven', 'get-enrollment', [
                types.principal(student.address),
                types.uint(1)
            ], student.address)
        ]);
        
        const enrollment = enrollmentBlock.receipts[0].result.expectSome().expectTuple();
        assertEquals(enrollment.purchased, true);
    }
});

Clarinet.test({
    name: "Test course rating",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const instructor = accounts.get('wallet_1')!;
        const student = accounts.get('wallet_2')!;
        
        // Create and purchase course
        chain.mineBlock([
            Tx.contractCall('skill_haven', 'create-course', [
                types.ascii("Learn Pottery"),
                types.utf8("A comprehensive course on pottery making"),
                types.uint(100)
            ], instructor.address),
            Tx.contractCall('skill_haven', 'purchase-course', [
                types.uint(1)
            ], student.address)
        ]);
        
        // Rate course
        let ratingBlock = chain.mineBlock([
            Tx.contractCall('skill_haven', 'rate-course', [
                types.uint(1),
                types.uint(5)
            ], student.address)
        ]);
        
        ratingBlock.receipts[0].result.expectOk().expectBool(true);
        
        // Verify rating
        let enrollmentBlock = chain.mineBlock([
            Tx.contractCall('skill_haven', 'get-enrollment', [
                types.principal(student.address),
                types.uint(1)
            ], student.address)
        ]);
        
        const enrollment = enrollmentBlock.receipts[0].result.expectSome().expectTuple();
        assertEquals(enrollment['rating'], types.some(types.uint(5)));
    }
});